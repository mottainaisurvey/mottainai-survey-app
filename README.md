# Mottainai Survey Mobile App

Flutter mobile application for waste management pickup submissions with offline support, role-based lot filtering, and ArcGIS integration.

## 🚀 Features

- **Role-Based Lot Access**: Users see only their company's lots; cherry pickers see all lots
- **Offline Support**: Submit pickups without internet connection, sync when online
- **ArcGIS Integration**: Interactive map with building polygons and location selection
- **Photo Capture**: Take before/after photos of pickup locations
- **Local Caching**: Cache lots, buildings, and user data for offline use
- **JWT Authentication**: Secure login with token-based authentication

## 📋 Prerequisites

- Flutter SDK 3.5.4+
- Android SDK (for Android builds)
- Xcode (for iOS builds, macOS only)
- Backend API running at configured endpoint

## 🛠️ Installation

\`\`\`bash
# Clone the repository
git clone https://github.com/mottainaisurvey/mottainai-survey-app.git
cd mottainai-survey-app

# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build APK for Android
flutter build apk --release
\`\`\`

## ⚙️ Configuration

Update API endpoint in \`lib/services/api_service.dart\`

## 📞 Support

For issues or questions, contact the development team.

**Current Version**: 2.9.5+13  
**Backend API**: https://admin.kowope.xyz
