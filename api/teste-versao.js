const { setCorsHeaders } = require('./middleware/cors');

module.exports = (req, res) => {
  setCorsHeaders(req, res);
  res.status(200).json({ versao: '3.0', timestamp: Date.now() });
};
