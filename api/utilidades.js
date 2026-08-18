const admin = require('firebase-admin');
const { setCorsHeaders } = require('./middleware/cors');

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

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try {
        const body = Buffer.concat(chunks).toString();
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        reject(new Error('Body inválido: ' + e.message));
      }
    });
    req.on('error', reject);
  });
}

async function ping(_req, res) {
  return res.status(200).json({ message: 'O servidor da Vercel esta VIVO e a funcionar!' });
}

async function versao(_req, res) {
  return res.status(200).json({ versao: '3.0', timestamp: Date.now() });
}

async function migrar(req, res) {
  try {
    const bodyData = await parseBody(req);
    const { secret } = bodyData;
    if (secret !== 'MIGRACAO_LEITURAS_2026') {
      return res.status(403).json({ error: 'Secret inválido.' });
    }

    const firestore = getDb();

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
}

async function verificarAuditoria(_req, res) {
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
}

module.exports = async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(200).end();

  const action = req.query.action;

  if (action === 'ping') {
    return ping(req, res);
  }

  if (action === 'versao') {
    return versao(req, res);
  }

  if (req.method === 'POST' && action === 'migrar') {
    return migrar(req, res);
  }

  if (action === 'verificar-auditoria') {
    return verificarAuditoria(req, res);
  }

  return res.status(400).json({ error: 'Ação inválida. Use ?action=ping, versao, migrar, ou verificar-auditoria.' });
};
