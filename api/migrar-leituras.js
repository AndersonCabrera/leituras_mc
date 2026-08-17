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
  res.setHeader('Access-Control-Allow-Methods', 'OPTIONS, POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Apenas POST.' });

  try {
    const { secret } = req.body;
    if (secret !== 'MIGRACAO_LEITURAS_2026') {
      return res.status(403).json({ error: 'Secret inválido.' });
    }

    const firestore = getDb();

    // 1. Buscar prédios
    const prediosSnap = await firestore.collection('predios').get();
    const mapaPredios = {};
    prediosSnap.forEach(doc => {
      const dados = doc.data();
      const nome = (dados.nome_predio || dados.nome || '').toLowerCase().trim();
      const idAdmin = dados.id_administradora || dados.admin_id;
      if (nome && idAdmin) {
        mapaPredios[nome] = idAdmin;
      }
    });

    // 2. Buscar todas as leituras
    const leiturasSnap = await firestore.collection('leituras').get();

    let atualizadas = 0;
    let semAdmin = 0;
    let erros = 0;

    for (const doc of leiturasSnap.docs) {
      const dados = doc.data();
      if (dados.id_administradora) continue;

      const condominio = (dados.condominio || '').toLowerCase().trim();
      const idAdmin = mapaPredios[condominio];

      if (idAdmin) {
        try {
          await doc.ref.update({ id_administradora: idAdmin });
          atualizadas++;
        } catch (e) {
          erros++;
        }
      } else {
        semAdmin++;
      }
    }

    return res.status(200).json({
      total: leiturasSnap.size,
      atualizadas,
      semAdmin,
      erros,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
