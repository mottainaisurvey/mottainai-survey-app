import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/pickup_submission.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mottainai.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const textNullable = 'TEXT';

    await db.execute('''
    CREATE TABLE pickups (
      id $idType,
      formId $textType,
      supervisorId $textType,
      customerType $textType,
      binType $textType,
      wheelieBinType $textNullable,
      binQuantity $intType,
      buildingId $textType,
      pickUpDate $textType,
      firstPhoto $textType,
      secondPhoto $textType,
      incidentReport $textNullable,
      userId $textType,
      latitude REAL,
      longitude REAL,
      synced INTEGER NOT NULL DEFAULT 0,
      createdAt $textType
    )
    ''');

    await db.execute('''
    CREATE TABLE cached_polygons (
      buildingId $textType,
      businessName $textNullable,
      custPhone $textNullable,
      customerEmail $textNullable,
      address $textNullable,
      zone $textNullable,
      socioEconomicGroups $textNullable,
      geometry $textType,
      centerLat REAL NOT NULL,
      centerLon REAL NOT NULL,
      lastUpdated INTEGER NOT NULL
    )
    ''');

    // Create index for faster spatial queries
    await db.execute('''
    CREATE INDEX idx_polygon_location ON cached_polygons(centerLat, centerLon)
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Add polygon cache table
      const textType = 'TEXT NOT NULL';
      const textNullable = 'TEXT';
      
      await db.execute('''
      CREATE TABLE cached_polygons (
        buildingId $textType,
        businessName $textNullable,
        custPhone $textNullable,
        customerEmail $textNullable,
        address $textNullable,
        zone $textNullable,
        socioEconomicGroups $textNullable,
        geometry $textType,
        centerLat REAL NOT NULL,
        centerLon REAL NOT NULL,
        lastUpdated INTEGER NOT NULL
      )
      ''');

      await db.execute('''
      CREATE INDEX idx_polygon_location ON cached_polygons(centerLat, centerLon)
      ''');
    }
    
    if (oldVersion < 4) {
      // Clear polygon cache to force re-sync with corrected JSON format
      await db.execute('DELETE FROM cached_polygons');
    }
  }

  Future<int> createPickup(PickupSubmission pickup) async {
    final db = await instance.database;
    return await db.insert('pickups', pickup.toMap());
  }

  Future<List<PickupSubmission>> getAllPickups() async {
    final db = await instance.database;
    final result = await db.query('pickups', orderBy: 'createdAt DESC');
    return result.map((json) => PickupSubmission.fromMap(json)).toList();
  }

  Future<List<PickupSubmission>> getUnsyncedPickups() async {
    final db = await instance.database;
    final result = await db.query(
      'pickups',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => PickupSubmission.fromMap(json)).toList();
  }

  Future<int> markAsSynced(int id) async {
    final db = await instance.database;
    return await db.update(
      'pickups',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePickup(int id) async {
    final db = await instance.database;
    return await db.delete(
      'pickups',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getUnsyncedCount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pickups WHERE synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ========== Polygon Cache Methods ==========
  
  Future<int> cachePolygon(Map<String, dynamic> polygon) async {
    final db = await instance.database;
    // Delete existing polygon with same buildingId
    await db.delete(
      'cached_polygons',
      where: 'buildingId = ?',
      whereArgs: [polygon['buildingId']],
    );
    return await db.insert('cached_polygons', polygon);
  }

  Future<void> cachePolygons(List<Map<String, dynamic>> polygons) async {
    final db = await instance.database;
    final batch = db.batch();
    
    for (var polygon in polygons) {
      // Delete existing
      batch.delete(
        'cached_polygons',
        where: 'buildingId = ?',
        whereArgs: [polygon['buildingId']],
      );
      // Insert new
      batch.insert('cached_polygons', polygon);
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedPolygons() async {
    final db = await instance.database;
    return await db.query('cached_polygons');
  }

  Future<Map<String, dynamic>?> getPolygonByBuildingId(String buildingId) async {
    final db = await instance.database;
    final result = await db.query(
      'cached_polygons',
      where: 'buildingId = ?',
      whereArgs: [buildingId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Get polygons within approximate radius (simple bounding box query)
  /// For production, consider using a proper spatial database or R-tree index
  Future<List<Map<String, dynamic>>> getPolygonsNearLocation({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
  }) async {
    final db = await instance.database;
    
    // Approximate degrees for radius (1 degree ≈ 111km)
    final latDelta = radiusKm / 111.0;
    final lonDelta = radiusKm / (111.0 * (lat.abs() > 0 ? lat.abs() / 90 : 1));
    
    final minLat = lat - latDelta;
    final maxLat = lat + latDelta;
    final minLon = lon - lonDelta;
    final maxLon = lon + lonDelta;
    
    return await db.query(
      'cached_polygons',
      where: 'centerLat BETWEEN ? AND ? AND centerLon BETWEEN ? AND ?',
      whereArgs: [minLat, maxLat, minLon, maxLon],
    );
  }

  Future<int> clearPolygonCache() async {
    final db = await instance.database;
    return await db.delete('cached_polygons');
  }

  Future<DateTime?> getLastPolygonCacheUpdate() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT MAX(lastUpdated) as maxTime FROM cached_polygons',
    );
    
    if (result.isNotEmpty && result.first['maxTime'] != null) {
      final timestamp = result.first['maxTime'] as int;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  Future<int> getPolygonCacheCount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM cached_polygons',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
