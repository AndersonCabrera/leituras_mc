const mercadopago = require('mercadopago');
const admin = require('firebase-admin');

mercadopago.configure({
  access_token: process.env.MP_ACCESS_TOKEN,
});

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'OPTIONS, POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Apenas POST.' });
  }

  try {
    const { id_administradora } = req.body;

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

    const assinaturaDoc = await admin
      .firestore()
      .collection('assinaturas')
      .doc(id_administradora)
      .get();

    if (!assinaturaDoc.exists) {
      return res.status(404).json({ error: 'Assinatura não encontrada.' });
    }

    const assinatura = assinaturaDoc.data();
    const mpId = assinatura?.id_mercadopago;

    if (mpId) {
      await mercadopago.preapproval.update({
        id: mpId,
        body: { status: 'cancelled' },
      });
    }

    await admin.firestore().collection('assinaturas').doc(id_administradora).update({
      status: 'cancelled',
      status_mercadopago: 'cancelled',
    });

    await admin.firestore().collection('administradoras').doc(id_administradora).update({
      status_assinatura: 'cancelled',
    });

    return res.status(200).json({ message: 'Assinatura cancelada com sucesso.' });
  } catch (error) {
    console.error('Erro ao cancelar:', error);
    return res.status(500).json({ error: 'Erro ao cancelar assinatura.' });
  }
};
