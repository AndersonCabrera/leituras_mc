const admin = require('firebase-admin');

module.exports = async (req, res) => {
  // 1. Sempre enviar os cabeçalhos de CORS primeiro! 
  // Isso impede que o Flutter Web mostre o erro genérico "Failed to fetch"
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
    // 2. Tentar ligar ao Firebase DENTRO do try/catch para apanharmos erros na chave
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          // Garante que o sistema processa bem as quebras de linha da chave secreta
          privateKey: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : undefined,
        })
      });
    }

    const { titulo, mensagem, destinatario_id, id_administradora } = req.body;

    if (!titulo || !mensagem || !id_administradora) {
      return res.status(400).json({ error: 'Título, mensagem e ID da administradora são obrigatórios.' });
    }

    let tokens = [];

    if (destinatario_id === 'todos' || !destinatario_id) {
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

    const response = await admin.messaging().sendEachForMulticast(payload);

    return res.status(200).json({
      message: 'Notificações disparadas com sucesso!',
      successCount: response.successCount,
      failureCount: response.failureCount
    });

  } catch (error) {
    console.error('Erro no Robô da Vercel:', error);
    // Se a chave do Firebase estiver errada, o erro vai finalmente aparecer no telemóvel!
    return res.status(500).json({ error: 'Erro interno no servidor Vercel.', details: error.message });
  }
};