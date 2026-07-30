const admin = require('firebase-admin');
const https = require('https');

function mpRequest(body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const options = {
      hostname: 'api.mercadopago.com',
      path: '/preapproval/',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.MP_ACCESS_TOKEN}`,
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
    return res.status(405).json({ error: 'Apenas POST é permitido.' });
  }

  try {
    const bodyData = await parseBody(req);
    const { id_administradora, plano, email, nome_empresa } = bodyData;

    if (!id_administradora || !plano || !email) {
      return res.status(400).json({
        error: 'id_administradora, plano e email são obrigatórios.',
      });
    }

    const precos = { premium: 127.0, super_premium: 297.0 };
    const nomes = {
      premium: 'Plano Premium - Leituras MC',
      super_premium: 'Plano Super Premium - Leituras MC',
    };

    if (!precos[plano]) {
      return res.status(400).json({ error: 'Plano inválido.' });
    }

    const { status: mpStatus, body: mpBody } = await mpRequest({
      reason: nomes[plano],
      payer_email: email,
      external_reference: id_administradora,
      auto_recurring: {
        frequency: 1,
        frequency_type: 'months',
        transaction_amount: precos[plano],
        currency_id: 'BRL',
      },
      back_url: 'https://leituras-mc.vercel.app/pagamento/retorno',
      status: 'pending',
    });

    if (mpStatus !== 200 && mpStatus !== 201) {
      return res.status(500).json({
        error: 'Erro MP',
        status_mp: mpStatus,
        details: mpBody,
      });
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

    await admin.firestore().collection('assinaturas').doc(id_administradora).set(
      {
        id_administradora,
        plano,
        status: 'pending',
        id_mercadopago: mpBody.id,
        status_mercadopago: mpBody.status,
        data_inicio: admin.firestore.FieldValue.serverTimestamp(),
        nome_empresa,
        email_admin: email,
      },
      { merge: true },
    );

    return res.status(200).json({
      url: mpBody.init_point,
      id_assinatura: mpBody.id,
      status: mpBody.status,
    });
  } catch (error) {
    console.error('Erro:', error);
    return res.status(500).json({
      error: 'Erro inesperado',
      details: error.message,
      stack: error.stack,
    });
  }
};
