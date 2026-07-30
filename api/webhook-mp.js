const admin = require('firebase-admin');
const https = require('https');

function mpGet(path) {
  return new Promise((resolve, reject) => {
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

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'OPTIONS, POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Apenas POST.' });

  try {
    const bodyData = await parseBody(req);
    const paymentId = bodyData.data?.id;
    if (!paymentId) return res.status(200).json({ message: 'Sem payment_id.' });

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
    const { body: payment } = await mpGet(`/v1/payments/${paymentId}`);
    const externalRef = payment.external_reference;
    if (!externalRef) return res.status(200).json({ message: 'Sem external_reference.' });

    const assinaturaRef = db.collection('assinaturas').doc(externalRef);
    const assinaturaDoc = await assinaturaRef.get();
    if (!assinaturaDoc.exists) return res.status(200).json({ message: 'Assinatura não encontrada.' });

    const assinatura = assinaturaDoc.data();
    const faturas = (assinatura.faturas || []).map((f) => {
      if (f.id_mp === paymentId) {
        return { ...f, status: payment.status, data_pagamento: admin.firestore.FieldValue.serverTimestamp() };
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
    console.error('Erro no webhook:', error);
    return res.status(200).json({ message: 'Webhook recebido.' });
  }
};
