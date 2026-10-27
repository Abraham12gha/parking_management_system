<div align="center">
  <img src="assets/images/PVS_LOGO.png" alt="Parking Management" width="112" />

  # Parking Management System

  **A multi-company parking operations app built with Flutter and Firebase.**

  Manage locations, staff, vehicle check-ins and check-outs, active parking,
  and operational reports from one workspace.

  ![Flutter](https://img.shields.io/badge/Flutter-desktop%20%26%20web-02569B?logo=flutter&logoColor=white)
  ![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase&logoColor=202124)
</div>

---

## Overview

Parking Management System helps parking teams handle daily operations in a shared application. Each company works in its own Firestore workspace, with company admins managing their locations and operators.

The app is built with Flutter. Firebase Authentication and Cloud Firestore provide sign-in and data storage; Cloudinary is used for company branding images.

## What it includes

| Workspace | Capabilities |
| --- | --- |
| **Platform administration** | Create companies and their first admin, review company status, manage plans, and process renewal or access-review requests. |
| **Company administration** | Manage locations, operators, company settings, and parking activity. |
| **Parking operations** | Record vehicle entry and exit, view active vehicles, and find completed parking records. |
| **Reports** | Review and save operational reports for admins and operators. |
| **Company isolation** | Store business records beneath a company-specific Firestore path and enforce access with Firestore Security Rules. |

Monthly and yearly plans are recorded in the app as an offline workflow. **There is no payment gateway or automatic payment verification.** A platform admin confirms payment and updates company access.

## Technology

- Flutter / Dart
- Firebase Authentication
- Cloud Firestore and Firestore Security Rules
- Cloudinary unsigned image uploads for company branding
- Firebase Emulator Suite for local Firestore rules verification

This repository uses a free-tier-compatible client architecture. It does not include a Node.js web server or deployed Cloud Functions. Platform-admin access is bootstrapped through the Firestore `platform_admins` allowlist; client apps cannot change that allowlist.

## Getting started

### Prerequisites

- Flutter SDK compatible with the Dart constraint in [`pubspec.yaml`](pubspec.yaml)
- A Firebase project with Authentication and Cloud Firestore enabled
- Firebase CLI for deploying rules or running emulators

### Install and run

```bash
git clone https://github.com/Abraham12gha/parking_management_system.git
cd parking_management_system
flutter pub get
flutter run
```

Select a supported device when prompted, or specify one with `flutter run -d <device-id>`.

### Firebase setup

The repository contains Firebase client configuration in `lib/firebase_options.dart` and project configuration in `firebase.json`. Confirm these point to the Firebase project you intend to use before running or deploying.

1. Enable the **Email/Password** provider in Firebase Authentication.
2. Create the platform owner's Auth account.
3. In Firestore, create `platform_admins/{AUTH_UID}` with the Boolean field `enabled: true`.
4. Deploy the Firestore rules and indexes:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes --project <firebase-project-id>
   ```

5. Configure the existing Cloudinary unsigned upload preset to accept a `folder` parameter. Company branding uploads use `companies/{companyId}/branding`.

Read [the free-tier tenant setup guide](docs/FREE_TENANT_SETUP.md) before setting up a new project or migrating existing flat Firestore data. The migration script defaults to a dry run and preserves source documents.

## Tenant data model

Company business data is stored under the company document:

```text
companies/{companyId}
├── users/{uid}
├── app_settings/{settingsId}
├── locations/{locationId}
├── parking_tickets/{ticketId}
├── backup/{ticketId}
├── saved_reports/{reportId}
├── report_states/{ownerId}
└── billing_requests/{requestId}

tenant_users/{uid}       # minimal membership lookup used after sign-in
platform_admins/{uid}    # manually managed platform-admin allowlist
```

`TenantContext` resolves the signed-in user's company and centralizes tenant-scoped Firestore references. Rules in [`firestore.rules`](firestore.rules) authorize access using the user's membership, role, and company status. Do not treat UI role checks as a security boundary; deploy the rules to enforce access in Firebase.

## Development and verification

Run Flutter's static checks and tests:

```bash
flutter analyze
flutter test
```

Run the Firestore rules tests with the Firebase Emulator Suite:

```bash
firebase emulators:start --only auth,firestore
npm --prefix tools install
npm --prefix tools run test:rules
```

The legacy-data migration helper is also in `tools/`. Use its dry-run mode first and follow the instructions in [the setup guide](docs/FREE_TENANT_SETUP.md). Keep Firebase service-account credentials outside the repository; never commit them.

## Repository layout

```text
lib/
├── admin_app/       # Platform and company administration
├── operator_app/    # Parking operator workflows
├── services/        # Auth, tenant context, Firestore and Cloudinary services
├── app_model/       # Parking and location models
├── resources/       # Shared UI components and theme
├── auth_wrapper.dart
└── main.dart
assets/              # Images and branding assets
docs/                # Setup and migration guidance
tools/               # Local migration helper and Firestore rules tests
firestore.rules      # Firestore authorization policy
firebase.json        # Firebase CLI and emulator configuration
```

## Important security notes

- Keep Firestore rules deployed and reviewed whenever the data model changes.
- Never put service-account JSON, private API secrets, or privileged credentials in the Flutter client or Git.
- Firebase client API keys identify the Firebase app; protect data with Authentication, Firestore Security Rules, and appropriate Firebase project restrictions.
- Cloudinary uploads use an unsigned preset. Restrict that preset in Cloudinary and do not include an API secret in the app.
- The current free-tier design does not use Firebase custom claims or Cloud Functions. Follow the setup guide for its actual bootstrap and role model.

---

<div align="center">
  Built for simpler, clearer parking operations.
</div>
