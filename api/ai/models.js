module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY' });
  try {
    const r = await fetch('https://api.groq.com/openai/v1/models', { headers: { Authorization: `Bearer ${key}` } });
    const data = await r.json();
    return res.status(200).json(data);
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
};
