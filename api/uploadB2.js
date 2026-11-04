const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
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

module.exports = async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Apenas POST é permitido.' });

  const auth = await verificarAuth(req, res);
  if (!auth) return;

  try {
    const { base64, fileName, contentType = 'image/jpeg' } = req.body;

    if (!base64 || !fileName) {
      return res.status(400).json({ error: 'base64 e fileName são obrigatórios.' });
    }

    const base64Data = base64.replace(/^base64:/, '');
    const buffer = Buffer.from(base64Data, 'base64');

    if (buffer.length > 10 * 1024 * 1024) {
      return res.status(400).json({ error: 'Imagem muito grande (max 10MB).' });
    }

    const bucket = process.env.B2_BUCKET_NAME;
    const key = `comprovantes/${fileName}`;

    await s3.send(new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: buffer,
      ContentType: contentType,
    }));

    const signedUrl = await getSignedUrl(
      s3,
      new GetObjectCommand({ Bucket: bucket, Key: key }),
      { expiresIn: 604800 }
    );

    return res.status(200).json({ downloadUrl: signedUrl, fileKey: key });
  } catch (error) {
    console.error('Erro upload B2:', error.message);
    return res.status(500).json({ error: error.message || 'Erro interno no servidor.' });
  }
};
