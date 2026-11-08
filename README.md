# Almuerzo Listo

El menú del día en un enlace y los pedidos en orden, para restaurantes de corrientazo.

- `/` → página de presentación
- `/panel` → panel del restaurante (entrar con el correo, publicar el menú, ver los pedidos en vivo, enlace y QR)
- `/nombre-del-restaurante` → menú que ven los clientes, donde hacen el pedido y reciben su número

## Puesta en marcha (una sola vez)

### 1. Supabase (base de datos)
1. Entre a supabase.com → **New project**. Región: **South America (São Paulo)**. Guarde la contraseña de la base de datos en un lugar seguro.
2. Menú izquierdo → **SQL Editor** → **New query** → pegue todo `schema.sql` → **Run**.
3. **Project Settings → API**: copie la **Project URL** y la **anon public key** y péguelas en `config.js`.
4. **Authentication → URL Configuration**:
   - *Site URL*: la dirección de la página (por ejemplo `https://almuerzo-listo.vercel.app`, o el dominio cuando lo compre).
   - *Redirect URLs*: agregue `https://SU-DIRECCION/panel`.

### 2. GitHub (guardar el código)
1. github.com → **New repository** → nombre `almuerzo-listo` → Create.
2. **uploading an existing file** → arrastre todos los archivos de esta carpeta → **Commit changes**.

### 3. Vercel (publicar en internet)
1. vercel.com → entre con GitHub → **Add New → Project** → elija `almuerzo-listo` → **Deploy**.
2. Le da una dirección como `almuerzo-listo.vercel.app`. Póngala en Supabase (paso 1.4).

### 4. Probar
1. Abra `/panel`, entre con su correo y cree un restaurante de prueba.
2. Publique un menú.
3. En otro celular abra el enlace del restaurante y haga un pedido: debe aparecer al instante en el panel con su número.

### 5. Dominio propio (cuando quiera)
Compre el dominio (por ejemplo `.co`) y en Vercel → **Settings → Domains** agréguelo y siga las instrucciones. Luego actualice las URLs del paso 1.4.

## Próximos pasos
- Lectura del menú con IA desde una foto (requiere una llave de API y una función en el servidor).
- Bot oficial de WhatsApp (WhatsApp Business Platform) cuando haya restaurantes pagando.
- Límite de pedidos por minuto para evitar abusos.
