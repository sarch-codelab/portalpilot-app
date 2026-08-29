// Recomendaciones de upsell/cross-sell del POS.
// Función individual (Vercel prioriza archivos específicos sobre el catch-all).
const dispatcher = require('../../[...slug].js');

module.exports = async function handler(req, res) {
  return dispatcher.aiPosUpsellHandler(req, res);
};