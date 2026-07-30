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

    const assinatura = assinaturaDoc.exists ? assinaturaDoc.data() : null;
    const administradora = adminDoc.exists ? adminDoc.data() : null;

    const plano = administradora?.plano || assinatura?.plano || 'gratis';
    const status = administradora?.status_assinatura || assinatura?.status || 'trial';

    const precos = { gratis: 0, premium: 12700, super_premium: 29700 };
    const limitesCond = { gratis: 3, premium: 15, super_premium: -1 };
    const limitesLeit = { gratis: 3, premium: 15, super_premium: -1 };

    const faturas = (assinatura?.faturas || []).slice(-6).reverse();
    const ultimaFatura = faturas[0] || null;

    return res.status(200).json({
      plano,
      status_assinatura: status,
      preco_centavos: precos[plano] || 0,
      limite_condominios: limitesCond[plano] || 3,
      limite_leituristas: limitesLeit[plano] || 3,
      data_expiracao: assinatura?.data_expiracao || null,
      faturas,
      ultima_fatura: ultimaFatura,
    });
  } catch (error) {
    console.error('Erro ao verificar status:', error);
    return res.status(500).json({ error: 'Erro interno.' });
  }
};
