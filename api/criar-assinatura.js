const admin = require('firebase-admin');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'OPTIONS, POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Apenas POST é permitido.' });
  }

  try {
    const { id_administradora, plano, email, nome_empresa } = req.body;

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

    const body = {
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
    };

    console.log('Token (primeiros 20 chars):', process.env.MP_ACCESS_TOKEN?.substring(0, 20));
    console.log('Body enviado:', JSON.stringify(body));

    const mpRes = await fetch('https://api.mercadopago.com/preapproval/', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.MP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const result = await mpRes.json();

    console.log('Status MP:', mpRes.status);
    console.log('Resposta MP:', JSON.stringify(result));

    if (!mpRes.ok) {
      return res.status(500).json({
        error: 'Erro MP.',
        details: JSON.stringify(result),
        status_mp: mpRes.status,
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
        id_mercadopago: result.id,
        status_mercadopago: result.status,
        data_inicio: admin.firestore.FieldValue.serverTimestamp(),
        nome_empresa,
        email_admin: email,
      },
      { merge: true },
    );

    return res.status(200).json({
      url: result.init_point,
      id_assinatura: result.id,
      status: result.status,
    });
  } catch (error) {
    console.error('Erro ao criar assinatura:', error);
    return res.status(500).json({
      error: 'Erro ao criar assinatura no Mercado Pago.',
      details: error.message,
    });
  }
};
