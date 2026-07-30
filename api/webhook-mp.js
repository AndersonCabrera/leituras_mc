const admin = require('firebase-admin');

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
    const bodyData = await parseBody(req);
    const { type, data, action } = bodyData;

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

    if (type === 'payment' || (data && data.id)) {
      const paymentId = data.id;
      const mpRes = await fetch(
        `https://api.mercadopago.com/v1/payments/${paymentId}`,
        {
          headers: {
            Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}`,
          },
        },
      );
      const payment = await mpRes.json();

      const planoMap = {
        'Plano Premium - Leituras MC': 'premium',
        'Plano Super Premium - Leituras MC': 'super_premium',
      };

      const externalRef = payment.external_reference;
      const payerEmail = payment.payer?.email;

      let query = db.collection('assinaturas');
      let snapshot;

      if (externalRef) {
        snapshot = await query.where('id_mercadopago', '==', externalRef).get();
      } else if (payerEmail) {
        snapshot = await query.where('email_admin', '==', payerEmail).get();
      } else {
        snapshot = await query.where('status', '==', 'pending').limit(10).get();
      }

      if (snapshot.empty) {
        return res.status(200).json({ message: 'Nenhuma assinatura encontrada.' });
      }

      const assinaturaDoc = snapshot.docs[0];
      const assinaturaData = assinaturaDoc.data();
      const idAdministradora = assinaturaDoc.id;

      if (payment.status === 'approved') {
        const planoId = planoMap[payment.description] || assinaturaData.plano || 'premium';
        const precos = { premium: 12700, super_premium: 29700 };

        await db.collection('assinaturas').doc(idAdministradora).update({
          status: 'active',
          status_mercadopago: 'authorized',
          data_proximo_cobranca: new Date(
            Date.now() + 30 * 24 * 60 * 60 * 1000,
          ),
          ultimo_pagamento: admin.firestore.FieldValue.serverTimestamp(),
        });

        await db.collection('administradoras').doc(idAdministradora).update({
          plano: planoId,
          status_assinatura: 'active',
        });

        await db.collection('pagamentos').add({
          id_administradora: idAdministradora,
          id_mercadopago: paymentId,
          valor: precos[planoId] || 12700,
          status: 'approved',
          metodo: payment.payment_method?.id || 'unknown',
          data: admin.firestore.FieldValue.serverTimestamp(),
          plano: planoId,
        });

        return res.status(200).json({ message: 'Assinatura ativada com sucesso!' });
      }

      if (payment.status === 'rejected' || payment.status === 'cancelled') {
        await db.collection('pagamentos').add({
          id_administradora: idAdministradora,
          id_mercadopago: paymentId,
          valor: payment.transaction_amount
            ? Math.round(payment.transaction_amount * 100)
            : 0,
          status: payment.status,
          metodo: payment.payment_method?.id || 'unknown',
          data: admin.firestore.FieldValue.serverTimestamp(),
          plano: assinaturaData.plano || '',
        });
      }

      if (payment.status === 'refunded') {
        await db.collection('assinaturas').doc(idAdministradora).update({
          status: 'cancelled',
          status_mercadopago: 'cancelled',
        });
        await db.collection('administradoras').doc(idAdministradora).update({
          status_assinatura: 'cancelled',
        });
      }
    }

    if (action === 'preapproval' || type === 'subscription') {
      const subId = data.id;
      const mpRes = await fetch(
        `https://api.mercadopago.com/preapproval/${subId}`,
        {
          headers: {
            Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}`,
          },
        },
      );
      const sub = await mpRes.json();

      const snapshot = await db
        .collection('assinaturas')
        .where('id_mercadopago', '==', subId)
        .get();

      if (!snapshot.empty) {
        const doc = snapshot.docs[0];
        const idAdm = doc.id;

        if (sub.status === 'authorized') {
          await db.collection('assinaturas').doc(idAdm).update({
            status: 'active',
            status_mercadopago: 'authorized',
          });
          await db.collection('administradoras').doc(idAdm).update({
            status_assinatura: 'active',
          });
        }

        if (sub.status === 'cancelled') {
          await db.collection('assinaturas').doc(idAdm).update({
            status: 'cancelled',
            status_mercadopago: 'cancelled',
          });
          await db.collection('administradoras').doc(idAdm).update({
            status_assinatura: 'cancelled',
          });
        }

        if (sub.status === 'paused') {
          await db.collection('assinaturas').doc(idAdm).update({
            status: 'past_due',
            status_mercadopago: 'paused',
          });
          await db.collection('administradoras').doc(idAdm).update({
            status_assinatura: 'past_due',
          });
        }
      }
    }

    return res.status(200).json({ message: 'Webhook processado.' });
  } catch (error) {
    console.error('Erro no webhook:', error);
    return res.status(200).json({ message: 'Webhook recebido com erro (não crítico).' });
  }
};
