// api/app-version.js - Endpoint para verificar actualizaciones de la app
// GET /api/app-version
//
// NOTA DE VERSIONADO:
//   La app compara por `versionCode` (Android versionCode). Este endpoint debe
//   apuntar SIEMPRE a la version MAS ALTA publicada.
//   Los APKs se distribuir por GitHub Releases (mismo canal que v1.0.12),
//   NO por Supabase: el APK pesa ~112 MB y supera con creces el limite por
//   archivo del bucket.
//
// AL PUBLICAR:
//   1. Sube el APK a una release de GitHub.
//   2. Copia aqui su versionCode, versionName y apkUrl.
//   3. Si publicas una BETA, remember subir el versionCode de la SIGUIENTE
//      estable (p.ej. la estable de 1.0.14 deberia ser versionCode 15) para
//      que los usuarios de la beta reciban la estable por autoactualizacion.

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Método no permitido' });

  // Configuración de la última versión - ACTUALIZA ESTO AL SUBIR NUEVA VERSIÓN
  const latestVersion = {
    // Debe coincidir con el `+N` de version en pubspec.yaml (versionCode del APK)
    versionCode: 14,
    versionName: '1.0.14-beta',
    apkUrl: 'https://github.com/sarch-codelab/portalpilot-app/releases/download/v1.0.14-beta/PortalPilot-Android-v1.0.14-beta.apk',
    // Metadata de integridad. El cliente DartTodavía NO la valida:
    // hoy no compara hash antes de abrir el instalador.
    sha256: '0865FDC4F54821826411591FAC985E4AA063ECB8D7A7E1276872192797C5310B',
    fileSizeBytes: 118018394,
    channel: 'beta',
    forceUpdate: false,
    changelog: [
      'Autoactualización en app: consulta de versión, descarga y apertura del instalador.',
      'Permiso de instalar apps desconocidas con aviso al usuario.',
      'Suscripción al topic FCM app_updates para avisos de versión nueva.',
      'El splash muestra la versión real del binario en lugar de un texto fijo.'
    ],
    // Versiones anteriores a esta deben actualizar obligatoriamente.
    // Se mantiene en 8 durante la beta: no se fuerza a los usuarios a instalar la beta.
    minSupportedVersionCode: 8
  };

  return res.status(200).json(latestVersion);
};
