const crypto = require('crypto');
const { getFirebaseAdmin } = require('./middleware/auth');
const { setCorsHeaders } = require('./middleware/cors');

function mpGet(path) {
  return new Promise((resolve, reject) => {
    const https = require('https');
    const options = {
      hostname: 'api.mercadopago.com',
      path,
      method: 'GET',
      headers: { Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}` },
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

function verificarAssinaturaMP(req) {
  const webhookSecret = process.env.MP_WEBHOOK_SECRET;
  if (!webhookSecret) return true;

  const signature = req.headers['x-signature'];
  if (!signature) return false;

  const parts = {};
  signature.split(',').forEach(part => {
    const [key, value] = part.split('=');
    parts[key] = value;
  });

  const timestamp = parts.ts;
  const v1 = parts.v1;

  if (!timestamp || !v1) return false;

  const rawBody = req._rawBody || JSON.stringify(req.body);
  const payload = `${timestamp}.${rawBody}`;
  const expected = crypto.createHmac('sha256', webhookSecret).update(payload).digest('hex');

  return v1 === expected;
}

module.exports = async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Apenas POST.' });

  try {
    if (!verificarAssinaturaMP(req)) {
      return res.status(401).json({ error: 'Assinatura do Mercado Pago inválida.' });
    }

    const bodyData = await parseBody(req);
    const paymentId = bodyData.data?.id;
    if (!paymentId) return res.status(200).json({ message: 'Sem payment_id.' });

    const admin = getFirebaseAdmin();
    const db = admin.firestore();

    const { body: payment } = await mpGet(`/v1/payments/${paymentId}`);
    const externalRef = payment.external_reference;
    if (!externalRef) return res.status(200).json({ message: 'Sem external_reference.' });

    const assinaturaRef = db.collection('assinaturas').doc(externalRef);
    const assinaturaDoc = await assinaturaRef.get();
    if (!assinaturaDoc.exists) return res.status(200).json({ message: 'Assinatura não encontrada.' });

    const assinatura = assinaturaDoc.data();
    const faturas = (assinatura.faturas || []).map((f) => {
      if (f.id_mp === paymentId) {
        return { ...f, status: payment.status, data_pagamento: new Date() };
      }
      return f;
    });

    const updateData = { faturas };

    if (payment.status === 'approved') {
      updateData.status = 'active';
      updateData.ultimo_pagamento = admin.firestore.FieldValue.serverTimestamp();
      updateData.data_expiracao = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

      await db.collection('administradoras').doc(externalRef).update({
        status_assinatura: 'active',
        plano: assinatura.plano,
      });
    }

    if (payment.status === 'rejected' || payment.status === 'cancelled') {
      const temAtiva = faturas.some((f) => f.status === 'approved');
      if (!temAtiva) {
        updateData.status = 'past_due';
      }
    }

    await assinaturaRef.update(updateData);
    return res.status(200).json({ message: `Pagamento ${payment.status} processado.` });
  } catch (error) {
    console.error('Erro no webhook:', error.message);
    return res.status(200).json({ message: 'Webhook recebido.' });
  }
};
