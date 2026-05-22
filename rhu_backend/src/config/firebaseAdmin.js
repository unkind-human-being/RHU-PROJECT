const admin = require("firebase-admin");

let firebaseApp = null;

const initializeFirebaseAdmin = () => {
  if (firebaseApp) {
    return firebaseApp;
  }

  const encodedServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;

  if (!encodedServiceAccount) {
    console.warn(
      "FIREBASE_SERVICE_ACCOUNT_BASE64 is missing. FCM sending will be disabled."
    );
    return null;
  }

  try {
    const serviceAccountJson = Buffer.from(
      encodedServiceAccount,
      "base64"
    ).toString("utf8");

    const serviceAccount = JSON.parse(serviceAccountJson);

    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    console.log("Firebase Admin initialized.");

    return firebaseApp;
  } catch (error) {
    console.error("Firebase Admin initialization failed:", error.message);
    return null;
  }
};

const getFirebaseMessaging = () => {
  const app = initializeFirebaseAdmin();

  if (!app) {
    return null;
  }

  return admin.messaging();
};

module.exports = {
  initializeFirebaseAdmin,
  getFirebaseMessaging,
};