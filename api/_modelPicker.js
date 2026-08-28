// Model picker auto-descubridor: consulta la lista de modelos vivos de Groq
// y devuelve cadenas de fallback. Cachea 5 min para no golpear la API.
// Así si Groq depreca modelos, la app usa automáticamente los disponibles.

let cached = null;
let cachedAt = 0;
const CACHE_MS = 5 * 60 * 1000;

// Preferencias de chat: orden de calidad deseada (los que no existan se descartan).
const CHAT_PRIORITY = [
  'openai/gpt-oss-20b',
  'openai/gpt-oss-120b',
  'meta-llama/llama-3.3-70b-versatile',
  'llama-3.3-70b-versatile',
  'meta-llama/llama-3.1-8b-instant',
  'llama-3.1-8b-instant',
];

// Preferencias de visión: modelos multimodales (Groq: Qwen 3.6/3.8).
const VISION_PRIORITY = [
  'qwen/qwen3.6-27b',
  'qwen/qwen3.8-27b',
  'qwen/qwen3.5-27b',
  'llama-3.2-11b-vision-preview',
  'llama-3.2-90b-vision-preview',
];

async function fetchLiveModels(key) {
  try {
    const r = await fetch('https://api.groq.com/openai/v1/models', {
      headers: { Authorization: `Bearer ${key}` },
    });
    if (!r.ok) return null;
    const data = await r.json();
    const ids = (data.data || [])
      .map((m) => m && m.id)
      .filter(Boolean);
    return ids;
  } catch {
    return null;
  }
}

// Devuelve { chat: [...], vision: [...] } cadenas de fallback con modelos vivos.
async function pickModels(key, requested) {
  const now = Date.now();
  if (!cached || now - cachedAt > CACHE_MS) {
    const live = await fetchLiveModels(key);
    if (live && live.length) {
      cached = new Set(live.map((id) => String(id).trim()));
      cachedAt = now;
    }
  }

  const liveIds = cached;

  const buildChain = (priority, filter) => {
    const chain = [];
    const push = (id) => {
      if (!id || !['string', 'number'].includes(typeof id)) return;
      id = String(id).trim();
      if (!id) return;
      if (chain.includes(id)) return;
      if (liveIds && !liveIds.has(id) && id !== requested) return; // solo vivos salvo el pedido
      chain.push(id);
    };
    // El modelo pedido por el cliente (si lo hay) va primero.
    if (requested) push(requested);
    for (const id of priority) push(id);
    // Cualquier otro modelo vivo que coincida con el filtro (visión o genérico).
    if (liveIds) {
      for (const id of Array.from(liveIds)) {
        if (chain.length >= 5) break;
        if (filter && !filter(id)) continue;
        push(id);
      }
    }
    return chain;
  };

  const chat = buildChain(CHAT_PRIORITY, (id) => {
    const l = id.toLowerCase();
    // Evitar modelos de voz/whisper/guard y El sistema compuesto.
    if (/whisper|guard|compound|sarif|safety/i.test(l)) return false;
    return /gpt-oss|llama-3|qwen/i.test(l);
  });

  const vision = buildChain(VISION_PRIORITY, (id) => {
    const l = id.toLowerCase();
    if (/whisper|guard|compound|safety/i.test(l)) return false;
    // Visión: solo Qwen y los 3.2-vision (según docs actuales de Groq).
    return l.includes('qwen') || l.includes('vision');
  });

  return { chat, vision };
}

module.exports = { pickModels };