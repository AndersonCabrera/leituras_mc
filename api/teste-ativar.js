const admin = require('firebase-admin');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');

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
  const id = req.query.id || 'teste-flow3';

  try {
    await db.collection('assinaturas').doc(id).update({
      status: 'active',
      status_mercadopago: 'authorized',
      ultimo_pagamento: admin.firestore.FieldValue.serverTimestamp(),
    });

    await db.collection('administradoras').doc(id).update({
      plano: 'premium',
      status_assinatura: 'active',
    });

    res.json({ message: 'Assinatura ativada com sucesso!', id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};
