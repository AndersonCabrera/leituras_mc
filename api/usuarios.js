const { verificarAuth, verificarSuperAdmin, getFirebaseAdmin } = require('./middleware/auth');
const { setCorsHeaders } = require('./middleware/cors');

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString()));
      } catch (e) {
        reject(new Error('Body inválido: ' + e.message));
      }
    });
    req.on('error', reject);
  });
}

async function criarUsuario(req, res) {
  const auth = await verificarAuth(req, res);
  if (!auth) return;

  try {
    const { nome, email, senha, cargo, id_administradora, cpf, telefone } = req.body;

    if (!nome || !email || !senha) {
      return res.status(400).json({ error: 'Nome, email e senha são obrigatórios.' });
    }
    if (typeof senha !== 'string' || senha.length < 6) {
      return res.status(400).json({ error: 'A senha deve ter no mínimo 6 caracteres.' });
    }
    const emailRegex = /^[\w.-]+@[\w.-]+\.\w{2,}$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ error: 'Email inválido.' });
    }

    const admin = getFirebaseAdmin();
    const db = admin.firestore();
    const solicitante = auth.userData;

    let cargoFinal = cargo || 'leiturista';
    let idAdmFinal = id_administradora || null;

    if (solicitante.cargo === 'super_admin') {
      if (cargoFinal === 'admin' && !idAdmFinal) {
        return res.status(400).json({ error: 'Para criar um admin é necessário o id_administradora.' });
      }
      if (cargoFinal === 'leiturista' && !idAdmFinal) {
        return res.status(400).json({ error: 'Para criar um leiturista é necessário o id_administradora.' });
      }
    } else if (solicitante.cargo === 'admin') {
      if (cargoFinal !== 'leiturista') {
        return res.status(403).json({ error: 'Admin só pode criar leituristas.' });
      }
      idAdmFinal = solicitante.id_administradora;
    } else {
      return res.status(403).json({ error: 'Sem permissão para criar usuários.' });
    }

    try {
      await admin.auth().getUserByEmail(email);
      return res.status(409).json({ error: 'Já existe um usuário com este email.' });
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
    }

    if (cargoFinal === 'leiturista') {
      const admDoc = await db.collection('administradoras').doc(idAdmFinal).get();
      const planoId = admDoc.exists ? admDoc.data().plano || 'gratis' : 'gratis';
      const planos = { gratis: 3, premium: 15, super_premium: -1 };
      const limite = planos[planoId] ?? 3;
      if (limite !== -1) {
        const qtdSnap = await db
          .collection('usuarios')
          .where('id_administradora', '==', idAdmFinal)
          .where('cargo', '==', 'leiturista')
          .get();
        if (qtdSnap.size >= limite) {
          return res.status(400).json({ error: 'Limite de leituristas do plano atingido.' });
        }
      }
    }

    const userRecord = await admin.auth().createUser({
      email,
      password: senha,
      displayName: nome,
    });

    await db.collection('usuarios').doc(userRecord.uid).set({
      nome,
      nome_primeiro: nome.split(' ')[0] || nome,
      nome_sobrenome: nome.split(' ').slice(1).join(' ') || '',
      email,
      cpf: cpf ? cpf.replace(/\D/g, '') : '',
      telefone: telefone ? telefone.replace(/\D/g, '') : '',
      cargo: cargoFinal,
      id_administradora: idAdmFinal,
      data_cadastro: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ uid: userRecord.uid });
  } catch (error) {
    console.error('Erro ao criar usuário:', error.message);
    return res.status(500).json({ error: 'Erro interno no servidor.' });
  }
}

async function excluirUsuario(req, res) {
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
}

module.exports = async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(200).end();

  const action = req.query.action || req.body?.action;

  if (req.method === 'POST' && action === 'criar') {
    return criarUsuario(req, res);
  }

  if (req.method === 'POST' && action === 'excluir') {
    return excluirUsuario(req, res);
  }

  return res.status(400).json({ error: 'Ação inválida. Use ?action=criar ou ?action=excluir.' });
};
