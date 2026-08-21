# Parking Management System

A Flutter-based application for managing parking operations, featuring Admin and Operator roles, integrated with Firebase and Cloudinary.

## Project Structure (Modernized Feature-Based)

```text
parking_management_system/
├── assets/                   # Project assets (images, fonts, etc.)
│   └── images/               # Image assets
│       ├── Login_backgrund.jpg
│       └── PVS_LOGO.png
├── lib/                      # Flutter source code
│   ├── config/               # App-wide configurations
│   │   ├── app_config.dart
│   │   └── firebase_options.dart
│   ├── core/                 # Shared & common code
│   │   ├── theme/            # App themes and theme controllers
│   │   │   ├── app_theme.dart
│   │   │   └── theme_controller.dart
│   │   └── widgets/          # Shared reusable widgets
│   ├── features/             # Feature-based modules
│   │   ├── admin/            # Admin feature
│   │   │   └── presentation/ # Admin dashboards, sidebars, and settings
│   │   │       ├── add_operator_admin.dart
│   │   │       ├── admin_appbar.dart
│   │   │       ├── admin_dashboard.dart
│   │   │       ├── admin_sidebar.dart
│   │   │       ├── dashboard_screen.dart
│   │   │       └── settings_admin.dart
│   │   ├── auth/             # Authentication feature
│   │   │   ├── data/         # Data sources & repositories
│   │   │   ├── domain/       # Entities & use cases
│   │   │   └── presentation/ # Auth UI (Login, Auth Wrapper)
│   │   │       ├── auth_wrapper.dart
│   │   │       └── login_screen.dart
│   │   ├── company/          # Company management feature
│   │   ├── operator/         # Operator feature
│   │   │   └── presentation/ # Operator dashboards
│   │   │       └── operator_dashboard.dart
│   │   └── parking/          # Parking core logic feature
│   ├── infrastructure/       # External service implementations
│   │   └── cloudinary/       # Cloudinary integration
│   ├── services/             # General utility services
│   │   ├── auth.dart
│   │   ├── app_title_bar.dart
│   │   └── cloudinary_service.dart
│   ├── app.dart              # Root application widget
│   └── main.dart             # Application entry point
├── test/                     # Unit and widget tests
├── pubspec.yaml              # Project dependencies
└── README.md                 # Project documentation
```

## Getting Started

1.  **Clone the repository.**
2.  **Install dependencies:** `flutter pub get`
3.  **Run the application:** `flutter run`

For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/).
