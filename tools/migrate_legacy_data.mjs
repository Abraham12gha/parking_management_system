import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const args = new Map();
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i].startsWith('--')) {
    const key = process.argv[i].slice(2);
    args.set(key, process.argv[i + 1]?.startsWith('--') ? 'true' : process.argv[++i]);
  }
}

const apply = args.has('apply');
const projectId = args.get('project-id') ?? process.env.FIREBASE_PROJECT_ID;
const companyId = args.get('company-id') ?? 'legacy-company';
const companyName = args.get('company-name');
const adminUid = args.get('admin-uid');
if (!projectId || !companyName || !adminUid) {
  console.error('Usage: node tools/migrate_legacy_data.mjs --project-id PROJECT --company-name "Legacy tenant name" --admin-uid UID [--company-id legacy-company] [--apply]');
  console.error('Without --apply, the script only prints a dry run. It never deletes source documents.');
  process.exit(2);
}

initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const sourceCollections = [
  'users',
  'locations',
  'counters',
  'parking_tickets',
  'backup',
  'app_settings',
  'saved_reports',
  'report_states',
];

const companyRef = db.collection('companies').doc(companyId);
const companySnapshot = await companyRef.get();
const conflicts = [];
if (companySnapshot.exists && companySnapshot.data()?.ownerUid !== adminUid) {
  conflicts.push(`companies/${companyId} already exists with a different owner uid`);
}
const userSnapshot = await db.collection('users').get();
if (!companySnapshot.exists) {
  const adminDoc = userSnapshot.docs.find((doc) => doc.id === adminUid);
  if (!adminDoc) throw new Error(`Admin uid ${adminUid} is not present in the legacy users collection.`);
}

const copyCandidates = [];
for (const collectionName of sourceCollections) {
  const source = await db.collection(collectionName).get();
  console.log(`${collectionName}: ${source.size} legacy documents`);
  for (const sourceDoc of source.docs) {
    const sourceData = sourceDoc.data();
    if (sourceData.companyId && sourceData.companyId !== companyId) {
      conflicts.push(`${collectionName}/${sourceDoc.id} already has companyId=${sourceData.companyId}`);
      continue;
    }
    const target = companyRef.collection(collectionName).doc(sourceDoc.id);
    const existing = await target.get();
    if (existing.exists) {
      console.log(`  skip existing target ${target.path}`);
      continue;
    }
    const targetData = { ...sourceData, companyId };
    if (collectionName === 'users') {
      targetData.role = sourceDoc.id === adminUid || sourceData.role === 'admin' ? 'admin' : 'operator';
      targetData.status = sourceData.disabled === true || sourceData.status === 'disabled' ? 'disabled' : 'active';
    }
    copyCandidates.push({ target, data: targetData });
  }
}

const memberships = [];
for (const userDoc of userSnapshot.docs) {
  const data = userDoc.data();
  const role = userDoc.id === adminUid ? 'admin' : data.role === 'admin' ? 'admin' : 'operator';
  const status = data.disabled === true || data.status === 'disabled' ? 'disabled' : 'active';
  const membershipRef = db.collection('tenant_users').doc(userDoc.id);
  const membership = await membershipRef.get();
  if (membership.exists) {
    if (membership.data()?.companyId !== companyId) {
      conflicts.push(`tenant_users/${userDoc.id} is already assigned to another company`);
    }
    continue;
  }
  memberships.push({
    ref: membershipRef,
    data: {
      companyId,
      role,
      status,
      name: data.firstName ?? data.name ?? '',
      email: data.email ?? '',
      location: data.location ?? '',
      createdAt: data.createdAt ?? FieldValue.serverTimestamp(),
    },
  });
}

const existingAdminProfile = await companyRef.collection('users').doc(adminUid).get();
if (existingAdminProfile.exists && (
  existingAdminProfile.data()?.role !== 'admin' ||
  existingAdminProfile.data()?.companyId !== companyId
)) {
  conflicts.push(`companies/${companyId}/users/${adminUid} already exists without the admin role`);
}
const adminProfileExists = existingAdminProfile.exists || copyCandidates.some(
  (candidate) => candidate.target.path === `companies/${companyId}/users/${adminUid}`,
);
if (!adminProfileExists && !userSnapshot.docs.some((doc) => doc.id === adminUid)) {
  conflicts.push(`No legacy admin profile exists for ${adminUid}`);
}

console.log(`\nTarget: companies/${companyId} (${companyName})`);
console.log(`Membership records to create: ${memberships.length}`);
console.log(`Tenant data documents to copy: ${copyCandidates.length}`);
console.log(`Conflicts skipped: ${conflicts.length}`);
for (const conflict of conflicts) console.warn(`  CONFLICT: ${conflict}`);
if (!apply) {
  console.log('\nDRY RUN only. Re-run with --apply to copy missing target documents.');
  process.exit(0);
}
if (conflicts.length > 0) {
  console.error('\nApply stopped because the dry run found conflicts. Resolve them and run the dry run again.');
  process.exit(1);
}

if (!companySnapshot.exists) {
  await companyRef.create({
    name: companyName,
    plan: 'monthly',
    billingCycle: 'monthly',
    paymentStatus: 'pending',
    status: 'active',
    ownerUid: adminUid,
    limits: {},
    createdAt: FieldValue.serverTimestamp(),
  });
} else {
  console.log('Company document already exists; preserving it without changes.');
}

const writes = [
  ...copyCandidates.map(({ target, data }) => ({ ref: target, data })),
  ...memberships.map(({ ref, data }) => ({ ref, data })),
];
for (let offset = 0; offset < writes.length; offset += 400) {
  const batch = db.batch();
  for (const { ref, data } of writes.slice(offset, offset + 400)) {
    batch.create(ref, data);
  }
  await batch.commit();
}
console.log(`\nCopied ${writes.length} missing documents. Legacy flat collections were left untouched.`);
