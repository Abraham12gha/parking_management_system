import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-parking-management';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const records = [
      ['companies/companyA', { name: 'Company A', status: 'active', ownerUid: 'adminA' }],
      ['companies/companyB', { name: 'Company B', status: 'active', ownerUid: 'adminB' }],
      ['tenant_users/adminA', { companyId: 'companyA', role: 'admin', status: 'active' }],
      ['tenant_users/operatorA', { companyId: 'companyA', role: 'operator', status: 'active', location: 'lot-1' }],
      ['users/operatorA', { role: 'operator' }],
      ['tenant_users/adminB', { companyId: 'companyB', role: 'admin', status: 'active' }],
      ['companies/companyA/users/adminA', { companyId: 'companyA', role: 'admin', status: 'active' }],
      ['companies/companyA/users/operatorA', { companyId: 'companyA', role: 'operator', status: 'active', location: 'lot-1' }],
      ['companies/companyB/users/adminB', { companyId: 'companyB', role: 'admin', status: 'active' }],
      ['platform_admins/platformOwner', { enabled: true }],
      ['app_settings/general', { appName: 'Legacy Company' }],
      ['locations/legacy-location', { locationName: 'Legacy Gate' }],
      ['companies/companyA/locations/lot-1', { locationName: 'Gate 1' }],
      ['companies/companyA/locations/lot-2', { locationName: 'Gate 2' }],
      ['companies/companyB/locations/lot-b', { locationName: 'Company B Gate' }],
      ['companies/companyA/parking_tickets/ticket-1', { locationId: 'lot-1', status: 'in' }],
      ['companies/companyA/parking_tickets/ticket-2', { locationId: 'lot-2', status: 'in' }],
      ['companies/companyA/memberships/member-1', {
        fullName: 'Test Member', vehicleNumber: 'ABC-123', phoneNumber: '5550100',
        locationId: 'lot-1', durationMonths: 3, amount: 1200, status: 'active',
        startsAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
        expiresAt: Timestamp.fromDate(new Date(Date.now() + 60_000)),
      }],
    ];
    for (const [path, value] of records) {
      await setDoc(doc(db, path), value);
    }
  });
});

test('Company A cannot read or write Company B data', async () => {
  const db = env.authenticatedContext('adminA').firestore();
  await assertFails(getDoc(doc(db, 'companies/companyB/locations/lot-b')));
  await assertFails(setDoc(doc(db, 'companies/companyB/locations/new'), { locationName: 'Intrusion' }));
  await assertFails(getDoc(doc(db, 'locations/legacy-location')));
});

test('operators cannot manage users, locations, or company settings', async () => {
  const db = env.authenticatedContext('operatorA').firestore();
  await assertFails(setDoc(doc(db, 'companies/companyA/locations/new'), { locationName: 'New gate' }));
  await assertFails(setDoc(doc(db, 'companies/companyA/users/newOperator'), {
    companyId: 'companyA', role: 'operator', status: 'active',
  }));
  await assertFails(setDoc(doc(db, 'companies/companyA/app_settings/general'), { appName: 'Changed' }));
  await assertFails(setDoc(doc(db, 'tenant_users/operatorA'), {
    companyId: 'companyA', role: 'admin', status: 'active', location: 'lot-1',
  }));
});

test('operators can query tickets only for their assigned location', async () => {
  const db = env.authenticatedContext('operatorA').firestore();
  const ownQuery = query(
    collection(db, 'companies/companyA/parking_tickets'),
    where('locationId', '==', 'lot-1'),
  );
  const otherQuery = query(
    collection(db, 'companies/companyA/parking_tickets'),
    where('locationId', '==', 'lot-2'),
  );
  await assertSucceeds(getDocs(ownQuery));
  await assertFails(getDocs(otherQuery));
});

test('operators can read memberships only at their assigned location', async () => {
  const db = env.authenticatedContext('operatorA').firestore();
  const ownQuery = query(
    collection(db, 'companies/companyA/memberships'),
    where('locationId', '==', 'lot-1'),
  );
  const otherQuery = query(
    collection(db, 'companies/companyA/memberships'),
    where('locationId', '==', 'lot-2'),
  );
  await assertSucceeds(getDoc(doc(db, 'companies/companyA/memberships/member-1')));
  await assertSucceeds(getDocs(ownQuery));
  await assertFails(getDocs(otherQuery));
  await assertFails(setDoc(doc(db, 'companies/companyA/memberships/operator-created'), {
    fullName: 'Unauthorized', locationId: 'lot-1', status: 'active',
  }));
});

test('membership tickets must match a valid member and its gate', async () => {
  const db = env.authenticatedContext('operatorA').firestore();
  const validTicket = {
    locationId: 'lot-1', operatorId: 'operatorA', vehicleCategory: 'membership',
    membershipId: 'member-1', vehicleNumber: 'ABC-123',
    startTime: Timestamp.fromDate(new Date()),
  };
  await assertSucceeds(setDoc(doc(db, 'companies/companyA/parking_tickets/member-visit'), validTicket));
  await assertFails(setDoc(doc(db, 'companies/companyA/parking_tickets/wrong-plate'), {
    ...validTicket, vehicleNumber: 'XYZ-987',
  }));
  await assertFails(setDoc(doc(db, 'companies/companyA/parking_tickets/wrong-gate'), {
    ...validTicket, locationId: 'lot-2',
  }));
});

test('unauthenticated users and users without tenant membership get no data', async () => {
  const unauthenticated = env.unauthenticatedContext().firestore();
  const unassigned = env.authenticatedContext('unassigned').firestore();
  await assertFails(getDoc(doc(unauthenticated, 'companies/companyA/locations/lot-1')));
  await assertFails(getDoc(doc(unassigned, 'companies/companyA/locations/lot-1')));
  await assertFails(getDoc(doc(unassigned, 'locations/legacy-location')));
});

test('a company owner can create a company and admin membership atomically', async () => {
  const db = env.authenticatedContext('newOwner').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'companies/newCompany'), {
    name: 'New Company', plan: 'monthly', billingCycle: 'monthly',
    paymentStatus: 'pending', status: 'pending', ownerUid: 'newOwner', limits: {},
  });
  batch.set(doc(db, 'tenant_users/newOwner'), {
    companyId: 'newCompany', role: 'admin', status: 'active',
  });
  batch.set(doc(db, 'companies/newCompany/users/newOwner'), {
    companyId: 'newCompany', role: 'admin', status: 'active',
  });
  await assertSucceeds(batch.commit());
});

test('a manually allowlisted platform admin can provision a company and first admin', async () => {
  const db = env.authenticatedContext('platformOwner').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'companies/platformCreated'), {
    name: 'Platform Created', plan: 'yearly', billingCycle: 'yearly',
    paymentStatus: 'pending', status: 'pending', ownerUid: 'firstAdmin', limits: {},
  });
  batch.set(doc(db, 'tenant_users/firstAdmin'), {
    companyId: 'platformCreated', role: 'admin', status: 'active',
  });
  batch.set(doc(db, 'companies/platformCreated/users/firstAdmin'), {
    companyId: 'platformCreated', role: 'admin', status: 'active',
  });
  await assertSucceeds(batch.commit());
  await assertSucceeds(updateDoc(doc(db, 'companies/platformCreated'), {
    status: 'active', paymentStatus: 'paid',
  }));
  await assertSucceeds(getDocs(collection(db, 'companies')));
  await assertFails(setDoc(doc(db, 'platform_admins/attacker'), { enabled: true }));
});

test('company creation cannot claim that a payment was already verified', async () => {
  const db = env.authenticatedContext('fakePaidOwner').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'companies/fakePaid'), {
    name: 'Fake Paid', plan: 'yearly', billingCycle: 'yearly',
    paymentStatus: 'paid', status: 'active', ownerUid: 'fakePaidOwner', limits: {},
  });
  batch.set(doc(db, 'tenant_users/fakePaidOwner'), {
    companyId: 'fakePaid', role: 'admin', status: 'active',
  });
  batch.set(doc(db, 'companies/fakePaid/users/fakePaidOwner'), {
    companyId: 'fakePaid', role: 'admin', status: 'active',
  });
  await assertFails(batch.commit());
});

test('tenant admins cannot change billing or company status', async () => {
  const db = env.authenticatedContext('adminA').firestore();
  await assertFails(updateDoc(doc(db, 'companies/companyA'), {
    status: 'active', paymentStatus: 'paid',
  }));
});
