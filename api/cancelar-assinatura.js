const { verificarSuperAdmin, getFirebaseAdmin } = require('./middleware/auth');
const { setCorsHeaders } = require('./middleware/cors');

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString()));
      } catch (e) {
        reject(new Error('Body inválido: ' + e.message));
      }
    });
    req.on('error', reject);
  });
}

module.exports = async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Apenas POST.' });
  }

  const auth = await verificarSuperAdmin(req, res);
  if (!auth) return;

  try {
    const bodyData = await parseBody(req);
    const { id_administradora } = bodyData;

    if (!id_administradora) {
      return res.status(400).json({ error: 'id_administradora obrigatório.' });
    }

    const admin = getFirebaseAdmin();
    const db = admin.firestore();

    await db.collection('assinaturas').doc(id_administradora).update({
      status: 'cancelled',
    });

    await db.collection('administradoras').doc(id_administradora).update({
      status_assinatura: 'cancelled',
    });

    return res.status(200).json({ message: 'Assinatura cancelada com sucesso.' });
  } catch (error) {
    console.error('Erro ao cancelar assinatura:', error.message);
    return res.status(500).json({ error: 'Erro ao cancelar assinatura.' });
  }
};
