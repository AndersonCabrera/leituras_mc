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
    const { base64, fileName, contentType = 'image/jpeg' } = req.body;

    if (!base64 || !fileName) {
      return res.status(400).json({ error: 'base64 e fileName são obrigatórios.' });
    }

    // Remove prefixo "base64:" se vier
    const base64Data = base64.replace(/^base64:/, '');
    const buffer = Buffer.from(base64Data, 'base64');

    if (buffer.length > 10 * 1024 * 1024) {
      return res.status(400).json({ error: 'Imagem muito grande (max 10MB).' });
    }

    const admin = getFirebaseAdmin();
    const bucket = admin.storage().bucket();

    // Upload via Admin SDK (funciona no Spark plan)
    const file = bucket.file(`comprovantes/${fileName}`);
    await file.save(buffer, {
      metadata: {
        contentType,
        cacheControl: 'public, max-age=31536000',
      },
      resumable: false,
    });

    // Torna público e pega download URL
    await file.makePublic();
    const downloadUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;

    return res.status(200).json({ downloadUrl });
  } catch (error) {
    console.error('Erro no upload via Admin SDK:', error.message);
    return res.status(500).json({ error: error.message || 'Erro interno no servidor.' });
  }
};