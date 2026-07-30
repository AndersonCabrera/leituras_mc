module.exports = (req, res) => {
  res.status(200).json({ versao: '3.0', timestamp: Date.now() });
};
