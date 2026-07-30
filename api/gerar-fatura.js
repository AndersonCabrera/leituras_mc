const admin = require('firebase-admin');
const https = require('https');

function mpRequest(body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const options = {
      hostname: 'api.mercadopago.com',
      path: '/v1/payments',
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
      },
    };
    const req = https.request(options, (res) => {
      let chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString();
        try {
          resolve({ status: res.statusCode, body: JSON.parse(text) });
        } catch {
          resolve({ status: res.statusCode, body: { raw: text } });
        }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

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
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'OPTIONS, POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Apenas POST.' });
  }

  try {
    const { id_administradora } = await parseBody(req);
    if (!id_administradora) {
      return res.status(400).json({ error: 'id_administradora obrigatório.' });
    }

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

    const db = admin.firestore();
    const assinaturaDoc = await db.collection('assinaturas').doc(id_administradora).get();

    if (!assinaturaDoc.exists) {
      return res.status(404).json({ error: 'Assinatura não encontrada.' });
    }

    const assinatura = assinaturaDoc.data();
    const precos = { premium: 127.0, super_premium: 297.0 };
    const nomes = {
      premium: 'Plano Premium - Leituras MC',
      super_premium: 'Plano Super Premium - Leituras MC',
    };
    const valor = precos[assinatura.plano];
    if (!valor) return res.status(400).json({ error: 'Plano inválido.' });

    const { status: mpStatus, body: mpBody } = await mpRequest({
      transaction_amount: valor,
      description: `${nomes[assinatura.plano]} - ${new Date().toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })}`,
      payment_method_id: 'pix',
      external_reference: id_administradora,
      payer: { email: assinatura.email_admin },
    });

    if (mpStatus !== 200 && mpStatus !== 201) {
      return res.status(500).json({ error: 'Erro MP', details: mpBody });
    }

    const pix = mpBody.point_of_interaction?.transaction_data || {};
    const fatura = {
      id_mp: mpBody.id,
      status: mpBody.status,
      valor,
      data_vencimento: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      data_criacao: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('assinaturas').doc(id_administradora).update({
      status: 'pending',
      data_expiracao: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      faturas: admin.firestore.FieldValue.arrayUnion(fatura),
    });

    await db.collection('administradoras').doc(id_administradora).update({
      status_assinatura: 'pending',
    });

    return res.status(200).json({
      id_fatura: mpBody.id,
      status: mpBody.status,
      qr_code: pix.qr_code,
      qr_code_base64: pix.qr_code_base64,
      ticket_url: pix.ticket_url,
      expiracao: mpBody.date_of_expiration,
      valor,
    });
  } catch (error) {
    console.error('Erro:', error);
    return res.status(500).json({ error: 'Erro inesperado', details: error.message });
  }
};
