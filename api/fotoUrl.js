const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { verificarAuth } = require('./middleware/auth');
const { setCorsHeaders } = require('./middleware/cors');

const s3 = new S3Client({
  endpoint: `https://${process.env.B2_ENDPOINT}`,
  region: 'us-east-005',
  credentials: {
    accessKeyId: process.env.B2_KEY_ID,
    secretAccessKey: process.env.B2_APP_KEY,
  },
});

const PADRAO_ARQUIVO = /^comprovantes\/[A-Za-z0-9._-]+\.jpg$/;

module.exports = async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET' && req.method !== 'POST') {
    return res.status(405).json({ error: 'Apenas GET ou POST são permitidos.' });
  }

  const auth = await verificarAuth(req, res);
  if (!auth) return;

  try {
    const fileKey =
      req.method === 'GET' ? req.query.fileKey : req.body && req.body.fileKey;

    if (!fileKey || typeof fileKey !== 'string') {
      return res.status(400).json({ error: 'fileKey é obrigatório.' });
    }

    if (!PADRAO_ARQUIVO.test(fileKey)) {
      return res.status(400).json({ error: 'fileKey inválido.' });
    }

    const bucket = process.env.B2_BUCKET_NAME;

    const signedUrl = await getSignedUrl(
      s3,
      new GetObjectCommand({ Bucket: bucket, Key: fileKey }),
      { expiresIn: 604800 }
    );

    return res.status(200).json({ downloadUrl: signedUrl });
  } catch (error) {
    console.error('Erro ao gerar URL da foto:', error.message);
    return res.status(500).json({ error: error.message || 'Erro interno no servidor.' });
  }
};
