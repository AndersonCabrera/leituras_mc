const { verificarAdmin, verificarSuperAdmin, verificarAdminDaEmpresa, getFirebaseAdmin } = require('./middleware/auth');
const { setCorsHeaders } = require('./middleware/cors');

function mpRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const https = require('https');
    const crypto = require('crypto');
    const data = body ? JSON.stringify(body) : null;
    const options = {
      hostname: 'api.mercadopago.com',
      path,
      method,
      headers: {
        Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
    };
    if (data) {
      options.headers['Content-Length'] = Buffer.byteLength(data);
      options.headers['X-Idempotency-Key'] = crypto.randomUUID();
    }
    const req = https.request(options, (res) => {
      let chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString();
        try {
          resolve({ status: res.statusCode, body: JSON.parse(text) });
        } catch {
          resolve({ status: res.statusCode, body: { raw: text } });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

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

async function criarAssinatura(req, res) {
  const auth = await verificarAdmin(req, res);
  if (!auth) return;

  try {
    const bodyData = await parseBody(req);
    const { id_administradora, plano, email, nome_empresa } = bodyData;

    if (!id_administradora || !plano || !email) {
      return res.status(400).json({ error: 'id_administradora, plano e email são obrigatórios.' });
    }

    if (auth.userData.cargo !== 'super_admin' && auth.userData.id_administradora !== id_administradora) {
      return res.status(403).json({ error: 'Sem permissão para criar assinatura para esta empresa.' });
    }

    const precos = { premium: 127.0, super_premium: 297.0 };
    const nomes = {
      premium: 'Plano Premium - Leituras MC',
      super_premium: 'Plano Super Premium - Leituras MC',
    };

    if (!precos[plano]) {
      return res.status(400).json({ error: 'Plano inválido.' });
    }

    const { status: mpStatus, body: mpBody } = await mpRequest('POST', '/v1/payments', {
      transaction_amount: precos[plano],
      description: `${nomes[plano]} - ${new Date().toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })}`,
      payment_method_id: 'pix',
      external_reference: id_administradora,
      payer: { email },
    });

    if (mpStatus !== 200 && mpStatus !== 201) {
      return res.status(500).json({ error: 'Erro MP', status_mp: mpStatus, details: mpBody });
    }

    const admin = getFirebaseAdmin();
    const db = admin.firestore();
    const pix = mpBody.point_of_interaction?.transaction_data || {};

    await db.collection('assinaturas').doc(id_administradora).set({
      id_administradora,
      plano,
      status: 'pending',
      email_admin: email,
      nome_empresa,
      data_inicio: admin.firestore.FieldValue.serverTimestamp(),
      data_expiracao: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      faturas: [{
        id_mp: mpBody.id,
        status: mpBody.status,
        valor: precos[plano],
        data_vencimento: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
        data_criacao: new Date(),
      }],
    }, { merge: true });

    await db.collection('administradoras').doc(id_administradora).set({
      plano,
      status_assinatura: 'pending',
      nome_empresa,
    }, { merge: true });

    return res.status(200).json({
      id_fatura: mpBody.id,
      status: mpBody.status,
      qr_code: pix.qr_code,
      qr_code_base64: pix.qr_code_base64,
      ticket_url: pix.ticket_url,
      expiracao: mpBody.date_of_expiration,
      valor: precos[plano],
    });
  } catch (error) {
    console.error('Erro ao criar assinatura:', error.message);
    return res.status(500).json({ error: 'Erro inesperado ao criar assinatura.' });
  }
}

async function statusAssinatura(req, res) {
  try {
    const { id_administradora } = req.query;
    if (!id_administradora) {
      return res.status(400).json({ error: 'id_administradora é obrigatório.' });
    }

    const auth = await verificarAdminDaEmpresa(req, res, id_administradora);
    if (!auth) return;

    const admin = getFirebaseAdmin();
    const db = admin.firestore();

    const assinaturaDoc = await db.collection('assinaturas').doc(id_administradora).get();
    const adminDoc = await db.collection('administradoras').doc(id_administradora).get();

    const assinatura = assinaturaDoc.exists ? assinaturaDoc.data() : null;
    const administradora = adminDoc.exists ? adminDoc.data() : null;

    const plano = administradora?.plano || assinatura?.plano || 'gratis';
    const status = administradora?.status_assinatura || assinatura?.status || 'trial';

    const limitesCond = { gratis: 3, premium: 15, super_premium: -1 };
    const limitesLeit = { gratis: 3, premium: 15, super_premium: -1 };

    const faturas = (assinatura?.faturas || []).slice(-6).reverse();
    const ultimaFatura = faturas[0] || null;

    return res.status(200).json({
      plano,
      status_assinatura: status,
      limite_condominios: limitesCond[plano] || 3,
      limite_leituristas: limitesLeit[plano] || 3,
      data_expiracao: assinatura?.data_expiracao || null,
      faturas,
      ultima_fatura: ultimaFatura,
    });
  } catch (error) {
    console.error('Erro ao verificar status:', error.message);
    return res.status(500).json({ error: 'Erro interno.' });
  }
}

async function gerarFatura(req, res) {
  try {
    const bodyData = await parseBody(req);
    const { id_administradora } = bodyData;

    if (!id_administradora) {
      return res.status(400).json({ error: 'id_administradora obrigatório.' });
    }

    const auth = await verificarAdminDaEmpresa(req, res, id_administradora);
    if (!auth) return;

    const admin = getFirebaseAdmin();
    const db = admin.firestore();
    const assinaturaDoc = await db.collection('assinaturas').doc(id_administradora).get();

    if (!assinaturaDoc.exists) {
      return res.status(404).json({ error: 'Assinatura não encontrada.' });
    }

    const assinatura = assinaturaDoc.data();
    const precos = { premium: 127.0, super_premium: 297.0 };
    const nomes = {
      premium: 'Plano Premium - Leituras MC',
      super_premium: 'Plano Super Premium - Leituras MC',
    };
    const valor = precos[assinatura.plano];
    if (!valor) return res.status(400).json({ error: 'Plano inválido.' });

    const { status: mpStatus, body: mpBody } = await mpRequest('POST', '/v1/payments', {
      transaction_amount: valor,
      description: `${nomes[assinatura.plano]} - ${new Date().toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })}`,
      payment_method_id: 'pix',
      external_reference: id_administradora,
      payer: { email: assinatura.email_admin },
    });

    if (mpStatus !== 200 && mpStatus !== 201) {
      return res.status(500).json({ error: 'Erro MP' });
    }

    const pix = mpBody.point_of_interaction?.transaction_data || {};
    const fatura = {
      id_mp: mpBody.id,
      status: mpBody.status,
      valor,
      data_vencimento: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      data_criacao: new Date(),
    };

    await db.collection('assinaturas').doc(id_administradora).update({
      status: 'pending',
      data_expiracao: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      faturas: admin.firestore.FieldValue.arrayUnion(fatura),
    });

    await db.collection('administradoras').doc(id_administradora).update({
      status_assinatura: 'pending',
    });

    return res.status(200).json({
      id_fatura: mpBody.id,
      status: mpBody.status,
      qr_code: pix.qr_code,
      qr_code_base64: pix.qr_code_base64,
      ticket_url: pix.ticket_url,
      expiracao: mpBody.date_of_expiration,
      valor,
    });
  } catch (error) {
    console.error('Erro ao gerar fatura:', error.message);
    return res.status(500).json({ error: 'Erro inesperado ao gerar fatura.' });
  }
}

async function cancelarAssinatura(req, res) {
  const auth = await verificarSuperAdmin(req, res);
  if (!auth) return;

  try {
    const bodyData = await parseBody(req);
    const { id_administradora } = bodyData;

    if (!id_administradora) {
      return res.status(400).json({ error: 'id_administradora obrigatório.' });
    }

    const admin = getFirebaseAdmin();
    const db = admin.firestore();

    await db.collection('assinaturas').doc(id_administradora).update({ status: 'cancelled' });
    await db.collection('administradoras').doc(id_administradora).update({ status_assinatura: 'cancelled' });

    return res.status(200).json({ message: 'Assinatura cancelada com sucesso.' });
  } catch (error) {
    console.error('Erro ao cancelar assinatura:', error.message);
    return res.status(500).json({ error: 'Erro ao cancelar assinatura.' });
  }
}

module.exports = async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(200).end();

  const action = req.query.action;

  if (req.method === 'POST' && action === 'criar') {
    return criarAssinatura(req, res);
  }

  if (req.method === 'GET' && action === 'status') {
    return statusAssinatura(req, res);
  }

  if (req.method === 'POST' && action === 'gerar-fatura') {
    return gerarFatura(req, res);
  }

  if (req.method === 'POST' && action === 'cancelar') {
    return cancelarAssinatura(req, res);
  }

  return res.status(400).json({ error: 'Ação inválida. Use ?action=criar, status, gerar-fatura, ou cancelar.' });
};
