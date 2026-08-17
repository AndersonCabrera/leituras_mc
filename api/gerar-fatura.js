const { verificarAdminDaEmpresa, getFirebaseAdmin } = require('./middleware/auth');
const { setCorsHeaders } = require('./middleware/cors');

function mpRequest(body) {
  return new Promise((resolve, reject) => {
    const https = require('https');
    const crypto = require('crypto');
    const data = JSON.stringify(body);
    const options = {
      hostname: 'api.mercadopago.com',
      path: '/v1/payments',
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        'X-Idempotency-Key': crypto.randomUUID(),
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
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Apenas POST.' });
  }

  try {
    const bodyData = await parseBody(req);
    const { id_administradora } = bodyData;

    if (!id_administradora) {
      return res.status(400).json({ error: 'id_administradora obrigatório.' });
    }

    const auth = await verificarAdminDaEmpresa(req, res, id_administradora);
    if (!auth) return;

    const admin = getFirebaseAdmin();
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
      return res.status(500).json({ error: 'Erro MP' });
    }

    const pix = mpBody.point_of_interaction?.transaction_data || {};
    const fatura = {
      id_mp: mpBody.id,
      status: mpBody.status,
      valor,
      data_vencimento: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      data_criacao: new Date(),
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
    console.error('Erro ao gerar fatura:', error.message);
    return res.status(500).json({ error: 'Erro inesperado ao gerar fatura.' });
  }
};
