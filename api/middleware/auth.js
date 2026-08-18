const admin = require('firebase-admin');

let firebaseAdmin = null;

function getFirebaseAdmin() {
  if (!firebaseAdmin) {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          privateKey: process.env.FIREBASE_PRIVATE_KEY
            ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
            : undefined,
        }),
        storageBucket: process.env.FIREBASE_STORAGE_BUCKET || 'leituras-mc.firebasestorage.app',
      });
    }
    firebaseAdmin = admin;
  }
  return firebaseAdmin;
}

function getDb() {
  return getFirebaseAdmin().firestore();
}

async function verificarAuth(req, res) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Token de autenticação necessário.' });
    return null;
  }

  const token = authHeader.split('Bearer ')[1];
  if (!token) {
    res.status(401).json({ error: 'Token de autenticação vazio.' });
    return null;
  }

  try {
    const fb = getFirebaseAdmin();
    const decoded = await fb.auth().verifyIdToken(token);
    const db = getDb();
    const userDoc = await db.collection('usuarios').doc(decoded.uid).get();

    if (!userDoc.exists) {
      res.status(401).json({ error: 'Usuário não encontrado no banco de dados.' });
      return null;
    }

    return { uid: decoded.uid, userData: userDoc.data() };
  } catch (error) {
    console.error('Erro na verificação do token:', error.message);
    res.status(401).json({ error: 'Token de autenticação inválido ou expirado.' });
    return null;
  }
}

async function verificarSuperAdmin(req, res) {
  const auth = await verificarAuth(req, res);
  if (!auth) return null;

  if (auth.userData.cargo !== 'super_admin') {
    res.status(403).json({ error: 'Apenas super administradores podem executar esta ação.' });
    return null;
  }

  return auth;
}

async function verificarAdmin(req, res) {
  const auth = await verificarAuth(req, res);
  if (!auth) return null;

  const cargo = auth.userData.cargo;
  if (cargo !== 'admin' && cargo !== 'super_admin') {
    res.status(403).json({ error: 'Sem permissão de administrador.' });
    return null;
  }

  return auth;
}

async function verificarAdminDaEmpresa(req, res, id_administradora) {
  const auth = await verificarAdmin(req, res);
  if (!auth) return null;

  if (auth.userData.cargo !== 'super_admin' && auth.userData.id_administradora !== id_administradora) {
    res.status(403).json({ error: 'Sem permissão para esta empresa.' });
    return null;
  }

  return auth;
}

module.exports = {
  getFirebaseAdmin,
  getDb,
  verificarAuth,
  verificarSuperAdmin,
  verificarAdmin,
  verificarAdminDaEmpresa,
};
