const admin = require('firebase-admin');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'OPTIONS, GET');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    const { id_administradora } = req.query;

    if (!id_administradora) {
      return res.status(400).json({ error: 'id_administradora é obrigatório.' });
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

    const adminDoc = await admin
      .firestore()
      .collection('administradoras')
      .doc(id_administradora)
      .get();

    let assinatura = null;
    if (assinaturaDoc.exists) {
      assinatura = assinaturaDoc.data();
    }

    let administradora = null;
    if (adminDoc.exists) {
      administradora = adminDoc.data();
    }

    const plano = administradora?.plano || assinatura?.plano || 'gratis';
    const status = administradora?.status_assinatura || assinatura?.status || 'trial';

    const precos = { gratis: 0, premium: 12700, super_premium: 29700 };
    const limitesCond = { gratis: 3, premium: 15, super_premium: -1 };
    const limitesLeit = { gratis: 3, premium: 15, super_premium: -1 };

    return res.status(200).json({
      plano,
      status,
      preco_centavos: precos[plano] || 0,
      limite_condominios: limitesCond[plano] || 3,
      limite_leituristas: limitesLeit[plano] || 3,
      id_mercadopago: assinatura?.id_mercadopago || null,
      status_mercadopago: assinatura?.status_mercadopago || null,
      data_proximo_cobranca: assinatura?.data_proximo_cobranca || null,
    });
  } catch (error) {
    console.error('Erro ao verificar status:', error);
    return res.status(500).json({ error: 'Erro interno.' });
  }
};
