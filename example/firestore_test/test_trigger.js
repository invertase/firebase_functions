// Simple script to create a Firestore document and trigger the function
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

// Connect to emulator
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

const app = initializeApp({ projectId: 'demo-test' });
const db = getFirestore(app);

async function createUser() {
  console.log('Creating user document...');
  const userRef = db.collection('users').doc('test-user-123');
  await userRef.set({
    name: 'Test User',
    email: 'test@example.com',
    createdAt: new Date(),
  });
  console.log('User created!');

  // Give time for function to execute
  await new Promise(resolve => setTimeout(resolve, 1000));
  process.exit(0);
}

createUser().catch(console.error);
