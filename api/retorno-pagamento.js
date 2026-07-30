module.exports = async (req, res) => {
  const { preapproval_id, status } = req.query;
  const sucesso = status === 'authorized' || status === 'approved' || status === 'pending';
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Pagamento - Leituras MC</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0D47A1, #1565C0);
      min-height: 100vh; display: flex; align-items: center; justify-content: center;
    }
    .card {
      background: white; border-radius: 20px; padding: 40px; max-width: 420px;
      width: 90%; text-align: center; box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    }
    .icon { font-size: 64px; margin-bottom: 16px; }
    h1 { font-size: 24px; color: #1A1A2E; margin-bottom: 8px; }
    p { color: #666; font-size: 15px; line-height: 1.5; margin-bottom: 24px; }
    .btn {
      display: inline-block; padding: 14px 32px; border-radius: 12px;
      text-decoration: none; font-weight: bold; font-size: 16px;
      background: #0D47A1; color: white; transition: opacity 0.2s;
    }
    .btn:hover { opacity: 0.9; }
    .loader { border: 3px solid #f3f3f3; border-top: 3px solid #0D47A1;
      border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite;
      margin: 0 auto 16px; }
    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="card">
    ${sucesso ? `
      <div class="icon">&#10004;&#65039;</div>
      <h1>Assinatura Confirmada!</h1>
      <p>Seu plano foi ativado com sucesso. Você já pode voltar ao aplicativo e aproveitar todos os recursos.</p>
      <a href="https://leituras-mc.vercel.app" class="btn">Voltar ao App</a>
    ` : `
      <div class="icon">&#9200;</div>
      <h1>Aguardando Confirmação</h1>
      <p>Estamos processando seu pagamento. Assim que for confirmado, sua assinatura será ativada automaticamente.</p>
      <div class="loader"></div>
      <a href="https://leituras-mc.vercel.app" class="btn">Voltar ao App</a>
    `}
  </div>
</body>
</html>`;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.status(200).send(html);
};
