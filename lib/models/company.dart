class Company {
  final String id;
  final String companyId;
  final String companyName;
  final String pinCode; // 6-digit PIN for authentication
  final List<OperationalLot> operationalLots;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Company({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.pinCode,
    required this.operationalLots,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['_id'] as String,
      companyId: json['company_id'] as String,
      companyName: json['company_name'] as String,
      pinCode: json['pin_code'] as String? ?? '000000',
      operationalLots: (json['operational_lots'] as List<dynamic>)
          .map((lot) => OperationalLot.fromJson(lot as Map<String, dynamic>))
          .toList(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'company_id': companyId,
      'company_name': companyName,
      'pin_code': pinCode,
      'operational_lots': operationalLots.map((lot) => lot.toJson()).toList(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // For local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'companyName': companyName,
      'pinCode': pinCode,
      'operationalLots': operationalLots.map((lot) => lot.toMap()).toList(),
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] as String,
      companyId: map['companyId'] as String,
      companyName: map['companyName'] as String,
      pinCode: map['pinCode'] as String? ?? '000000',
      operationalLots: (map['operationalLots'] as List<dynamic>)
          .map((lot) => OperationalLot.fromMap(lot as Map<String, dynamic>))
          .toList(),
      isActive: (map['isActive'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}

class OperationalLot {
  final String lotCode;
  final String lotName;
  final String paytWebhook;
  final String monthlyWebhook;
  final String companyId;
  final String companyName;

  OperationalLot({
    required this.lotCode,
    required this.lotName,
    required this.paytWebhook,
    required this.monthlyWebhook,
    required this.companyId,
    required this.companyName,
  });

  factory OperationalLot.fromJson(Map<String, dynamic> json) {
    return OperationalLot(
      lotCode: json['lotCode'] as String? ?? json['lot_code'] as String,
      lotName: json['lotName'] as String? ?? json['lot_name'] as String,
      paytWebhook: json['paytWebhook'] as String? ?? json['payt_webhook'] as String,
      monthlyWebhook: json['monthlyWebhook'] as String? ?? json['monthly_webhook'] as String,
      companyId: json['companyId'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lotCode': lotCode,
      'lotName': lotName,
      'paytWebhook': paytWebhook,
      'monthlyWebhook': monthlyWebhook,
      'companyId': companyId,
      'companyName': companyName,
    };
  }

  // For local storage
  Map<String, dynamic> toMap() {
    return {
      'lotCode': lotCode,
      'lotName': lotName,
      'paytWebhook': paytWebhook,
      'monthlyWebhook': monthlyWebhook,
      'companyId': companyId,
      'companyName': companyName,
    };
  }

  factory OperationalLot.fromMap(Map<String, dynamic> map) {
    return OperationalLot(
      lotCode: map['lotCode'] as String,
      lotName: map['lotName'] as String,
      paytWebhook: map['paytWebhook'] as String,
      monthlyWebhook: map['monthlyWebhook'] as String,
      companyId: map['companyId'] as String? ?? '',
      companyName: map['companyName'] as String? ?? '',
    );
  }

  String get displayName => '$companyName - $lotName ($lotCode)';
}
