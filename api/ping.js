module.exports = (req, res) => {
  // Se este texto aparecer no navegador, a Vercel está a funcionar a 100%!
  res.status(200).json({ message: "O servidor da Vercel esta VIVO e a funcionar!" });
};