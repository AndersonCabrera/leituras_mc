const admin = require('firebase-admin');

// 1. Inicializa o Firebase com as "Chaves Secretas" que vamos colocar na Vercel
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      // A Vercel troca as quebras de linha por texto, isto corrige o problema:
      privateKey: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : undefined,
    })
  });
}

module.exports = async (req, res) => {
  // 2. Configuração de Segurança (CORS) para permitir que o Flutter converse com esta API
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
    const { titulo, mensagem, destinatario_id } = req.body;

    if (!titulo || !mensagem) {
      return res.status(400).json({ error: 'Título e mensagem são obrigatórios.' });
    }

    let tokens = [];

    // 3. Busca os "Números de Telefone" (Tokens) no Banco de Dados
    if (destinatario_id === 'todos' || !destinatario_id) {
      const usersSnap = await admin.firestore().collection('usuarios').where('cargo', '==', 'leiturista').get();
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
      return res.status(200).json({ message: 'Nenhum telemóvel registado. Ninguém foi notificado.', successCount: 0 });
    }

    // 4. Prepara o Pacote de Envio
    const payload = {
      tokens: tokens,
      notification: {
        title: titulo,
        body: mensagem
      }
    };

    // 5. Dispara a Notificação Push via satélite!
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