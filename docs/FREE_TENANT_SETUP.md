# Free tier multi-tenant setup

This implementation uses Firebase Auth and Firestore on the Spark plan. It does not deploy Cloud Functions or run a separate backend server. The `tools` Node scripts are local maintenance and test commands only.

## Platform admin bootstrap

1. Create the platform owner's Firebase Auth account in Firebase Console (or use an existing account).
2. In Firestore Console, create `platform_admins/{that-auth-uid}` with `{ "enabled": true }`.
3. Deploy `firestore.rules`. The client can read only its own platform-admin record; client writes to `platform_admins` are denied.

The platform-admin allowlist is manually provisioned because Spark has no trusted Cloud Functions runtime. There are no custom claims in this free-tier design.

## Create tenants

- A company can create its own account from the login screen. The creator becomes that tenant's first admin.
- A platform admin can create a company and first admin from Platform administration.
- Both flows write the company document, tenant membership index, and tenant user profile in one Firestore batch.
- New companies begin in `pending` status. The platform admin can confirm an offline payment and activate them from Platform administration.
- `plan` and `billingCycle` record the monthly or yearly selection. `paymentStatus` starts as `pending`. The app does not take or verify payment; update payment status only through a trusted manual process.

## Legacy data migration

Install the free local tooling packages:

```powershell
npm --prefix tools install
```

Authenticate the Firebase Admin SDK locally with Application Default Credentials (for example, `gcloud auth application-default login`) or set `GOOGLE_APPLICATION_CREDENTIALS` to a service-account JSON file kept outside this repository. Never commit that credential.

Run the dry run first. Choose a real name for the existing-data tenant; the script deliberately does not assume Pakistan Valet Solutions is the company name:

```powershell
$env:FIREBASE_PROJECT_ID = "your-firebase-project-id"
node tools/migrate_legacy_data.mjs --company-name "Your legacy tenant name" --admin-uid "existing-admin-auth-uid"
```

Review the reported counts and conflicts. To copy missing documents only, repeat the same command with `--apply`. It never deletes flat legacy documents, skips existing targets, and stops if it finds a conflicting company assignment.

## Emulator verification

```powershell
firebase emulators:start --only auth,firestore
npm --prefix tools run test:rules
```

The rules tests use the Firestore Emulator; Auth records are simulated with authenticated test contexts, so no real Auth users are created. The emulator configuration includes Auth for manual end-to-end sign-in checks.

## Cloudinary

Logo uploads use `companies/{companyId}/branding`. Confirm the existing unsigned upload preset accepts the `folder` field. No Cloudinary API secret is placed in the app.
