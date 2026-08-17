const { setCorsHeaders } = require('./middleware/cors');

module.exports = (req, res) => {
  setCorsHeaders(req, res);
  res.status(200).json({ message: "O servidor da Vercel esta VIVO e a funcionar!" });
};
