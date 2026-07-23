const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : undefined,
    })
  });
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'OPTIONS, POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Apenas método POST é permitido.' });
  }

  try {
    const { titulo, mensagem, destinatario_id, id_administradora } = req.body;

    if (!titulo || !mensagem || !id_administradora) {
      return res.status(400).json({ error: 'Título, mensagem e ID da administradora são obrigatórios.' });
    }

    let tokens = [];

    if (destinatario_id === 'todos' || !destinatario_id) {
      // 💡 CORRIGIDO: Agora filtra para enviar notificações apenas à equipa desta empresa específica!
      const usersSnap = await admin.firestore().collection('usuarios')
        .where('cargo', '==', 'leiturista')
        .where('id_administradora', '==', id_administradora)
        .get();
        
      usersSnap.forEach(doc => {
        if (doc.data().fcm_token) tokens.push(doc.data().fcm_token);
      });
    } else {
      const userDoc = await admin.firestore().collection('usuarios').doc(destinatario_id).get();
      if (userDoc.exists && userDoc.data().fcm_token) {
        tokens.push(userDoc.data().fcm_token);
      }
    }

    if (tokens.length === 0) {
      return res.status(200).json({ message: 'Nenhum telemóvel registado ou encontrado.', successCount: 0 });
    }

    const payload = {
      tokens: tokens,
      notification: {
        title: titulo,
        body: mensagem
      }
    };

    // 💡 CORRIGIDO: Utiliza a versão mais recente "sendEachForMulticast"
    const response = await admin.messaging().sendEachForMulticast(payload);

    return res.status(200).json({
      message: 'Notificações disparadas com sucesso!',
      successCount: response.successCount,
      failureCount: response.failureCount
    });

  } catch (error) {
    console.error('Erro no Robô da Vercel:', error);
    return res.status(500).json({ error: 'Erro interno no servidor.', details: error.message });
  }
};