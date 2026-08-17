const admin = require('firebase-admin');

let db = null;

function getDb() {
  if (!db) {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          privateKey: process.env.FIREBASE_PRIVATE_KEY
            ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
            : undefined,
        }),
      });
    }
    db = admin.firestore();
  }
  return db;
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'OPTIONS, GET');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Apenas GET.' });

  try {
    const firestore = getDb();
    const leiturasSnap = await firestore.collection('leituras').get();

    let comFoto = 0;
    let semIdAdmin = 0;
    let pendentes = 0;
    let aprovadas = 0;

    for (const doc of leiturasSnap.docs) {
      const dados = doc.data();
      if (dados.tem_foto_anexada === true) {
        comFoto++;
        if (!dados.id_administradora) semIdAdmin++;
        if (dados.status_auditoria === 'aprovado') aprovadas++;
        else pendentes++;
      }
    }

    return res.status(200).json({
      total_leituras: leiturasSnap.size,
      com_foto: comFoto,
      sem_id_admin: semIdAdmin,
      pendentes_auditoria: pendentes,
      aprovadas: aprovadas,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
