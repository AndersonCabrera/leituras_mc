const { verificarAdminDaEmpresa, getFirebaseAdmin } = require('./middleware/auth');
const { setCorsHeaders } = require('./middleware/cors');

module.exports = async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Apenas método POST é permitido.' });
  }

  try {
    const { titulo, mensagem, destinatario_id, id_administradora } = req.body;

    if (!titulo || !mensagem || !id_administradora) {
      return res.status(400).json({ error: 'Título, mensagem e ID da administradora são obrigatórios.' });
    }

    const auth = await verificarAdminDaEmpresa(req, res, id_administradora);
    if (!auth) return;

    const admin = getFirebaseAdmin();
    const db = admin.firestore();

    let tokens = [];

    if (destinatario_id === 'todos' || !destinatario_id) {
      const usersSnap = await db.collection('usuarios')
        .where('cargo', '==', 'leiturista')
        .where('id_administradora', '==', id_administradora)
        .get();

      usersSnap.forEach(doc => {
        if (doc.data().fcm_token) tokens.push(doc.data().fcm_token);
      });
    } else {
      const userDoc = await db.collection('usuarios').doc(destinatario_id).get();
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
    console.error('Erro ao enviar notificação:', error.message);
    return res.status(500).json({ error: 'Erro interno ao enviar notificação.' });
  }
};
