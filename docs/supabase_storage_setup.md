# Configuración de Supabase Storage para Imágenes de Productos

## Pasos para configurar el bucket de imágenes:

1. **Acceder a Supabase Dashboard**
   - Ve a https://supabase.com/dashboard
   - Selecciona tu proyecto (portalpilot-app)

2. **Crear el bucket de productos**
   - En el menú lateral, ve a "Storage"
   - Haz clic en "New bucket"
   - Nombre: `productos`
   - Haz clic en "Create bucket"

3. **Configurar políticas del bucket**
   - En el bucket `productos`, ve a "Policies"
   - Crea una nueva política con:
     - **Policy name**: `public_productos`
     - **Allowed operations**: `SELECT`, `INSERT`
     - **Target roles**: `anon`, `authenticated`
   - Esto permite que la app pueda subir y ver imágenes públicamente

4. **Crear la carpeta de imágenes (opcional)**
   - Dentro del bucket `productos`, crea una carpeta llamada `imagenes`
   - Esto mantiene las imágenes organizadas

## Variables de entorno (si son necesarias):

No se requieren variables adicionales para Supabase Storage ya que se usa la configuración existente de Supabase Flutter.

## Notas importantes:

- Las imágenes se subirán automáticamente cuando el usuario seleccione una foto en el formulario de productos
- Si la subida a Supabase Storage falla, el sistema usará data URLs como fallback
- Las URLs generadas serán públicas y accesibles desde cualquier lugar
- Las imágenes tienen un límite de ~400KB para optimizar el rendimiento