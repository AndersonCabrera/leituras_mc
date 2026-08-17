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
    const { nome, email, senha, cargo, id_administradora, cpf, telefone } =
      req.body;

    if (!nome || !email || !senha) {
      return res
        .status(400)
        .json({ error: 'Nome, email e senha são obrigatórios.' });
    }
    if (typeof senha !== 'string' || senha.length < 6) {
      return res
        .status(400)
        .json({ error: 'A senha deve ter no mínimo 6 caracteres.' });
    }
    const emailRegex = /^[\w.-]+@[\w.-]+\.\w{2,}$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ error: 'Email inválido.' });
    }

    const admin = getFirebaseAdmin();
    const db = admin.firestore();
    const solicitante = auth.userData;

    // Permissões
    let cargoFinal = cargo || 'leiturista';
    let idAdmFinal = id_administradora || null;

    if (solicitante.cargo === 'super_admin') {
      // Super admin pode criar admin (exige id_administradora) ou leiturista
      if (cargoFinal === 'admin' && !idAdmFinal) {
        return res
          .status(400)
          .json({ error: 'Para criar um admin é necessário o id_administradora.' });
      }
      if (cargoFinal === 'leiturista' && !idAdmFinal) {
        return res
          .status(400)
          .json({ error: 'Para criar um leiturista é necessário o id_administradora.' });
      }
    } else if (solicitante.cargo === 'admin') {
      // Admin só cria leituristas da própria administradora
      if (cargoFinal !== 'leiturista') {
        return res
          .status(403)
          .json({ error: 'Admin só pode criar leituristas.' });
      }
      idAdmFinal = solicitante.id_administradora;
    } else {
      return res.status(403).json({ error: 'Sem permissão para criar usuários.' });
    }

    // Verifica se o email já existe
    try {
      await admin.auth().getUserByEmail(email);
      return res.status(409).json({ error: 'Já existe um usuário com este email.' });
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
    }

    // Verifica limite do plano para leituristas
    if (cargoFinal === 'leiturista') {
      const admDoc = await db.collection('administradoras').doc(idAdmFinal).get();
      const planoId = admDoc.exists ? admDoc.data().plano || 'gratis' : 'gratis';
      const planos = {
        gratis: 3,
        premium: 15,
        super_premium: -1,
      };
      const limite = planos[planoId] ?? 3;
      if (limite !== -1) {
        const qtdSnap = await db
          .collection('usuarios')
          .where('id_administradora', '==', idAdmFinal)
          .where('cargo', '==', 'leiturista')
          .get();
        if (qtdSnap.size >= limite) {
          return res
            .status(400)
            .json({ error: 'Limite de leituristas do plano atingido.' });
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
};