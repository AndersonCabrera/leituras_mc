const { verificarAuth, getFirebaseAdmin } = require('./middleware/auth');
const { setCorsHeaders } = require('./middleware/cors');

module.exports = async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Apenas método POST é permitido.' });
  }

  const auth = await verificarAuth(req, res);
  if (!auth) return;

  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ error: 'O ID do usuário é obrigatório.' });
    }

    const admin = getFirebaseAdmin();
    const db = admin.firestore();

    const targetUserDoc = await db.collection('usuarios').doc(userId).get();
    if (!targetUserDoc.exists) {
      return res.status(404).json({ error: 'Usuário alvo não encontrado.' });
    }

    const targetUser = targetUserDoc.data();
    const cargo = auth.userData.cargo;

    if (cargo === 'super_admin') {
      // Super admin pode excluir qualquer um
    } else if (cargo === 'admin') {
      if (targetUser.id_administradora !== auth.userData.id_administradora) {
        return res.status(403).json({ error: 'Sem permissão para excluir este usuário.' });
      }
      if (targetUser.cargo === 'admin' || targetUser.cargo === 'super_admin') {
        return res.status(403).json({ error: 'Não é possível excluir outro administrador.' });
      }
    } else {
      return res.status(403).json({ error: 'Sem permissão para excluir usuários.' });
    }

    await admin.auth().deleteUser(userId);
    await db.collection('usuarios').doc(userId).delete();

    return res.status(200).json({ message: 'Usuário excluído com sucesso.' });
  } catch (error) {
    console.error('Erro ao excluir usuário:', error.message);
    return res.status(500).json({ error: 'Erro interno no servidor.' });
  }
};
