# Ommadawn (app)

App móvil que cataloga **el universo sonoro de Mike Oldfield**: discografía
(álbumes de estudio, recopilatorios, singles, directos, bootlegs…), conciertos,
libros y otras secciones. Es el **cliente** de la API
[`ommadawn-api`](#relación-con-la-api): todo el contenido lo sirve esa API y la
app lo presenta.

> Proyecto de aprendizaje, pero construido con criterio y con la intención de
> publicarse de verdad. Se avanza en **fases pequeñas y entendibles**,
> priorizando el *por qué* de cada decisión sobre la velocidad.

**iOS** (iPhone/iPad). Se evaluó dar soporte a macOS/visionOS y se descartó: además de
las adaptaciones de UI necesarias, macOS exige un entitlement de Keychain que a su vez
requiere un perfil de aprovisionamiento de equipo real — complejidad que no compensa
para esta app. Android queda para el futuro con otra base de código.

Ver el [plan por fases](#plan-por-fases) completo abajo — es la única fuente del estado
del proyecto, para no mantener el mismo resumen duplicado en dos sitios.

---

## Stack

| Tecnología | Función |
|---|---|
| Swift (modo de lenguaje 5, toolchain 6.x) | Lenguaje |
| SwiftUI + Observation (`@Observable`) | UI declarativa y estado |
| Swift Concurrency (`async/await`, actores) | Red y trabajo asíncrono sin bloquear la UI |
| [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) | Genera el cliente HTTP tipado desde el `openapi.json` |
| [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) | Transporte HTTP sobre URLSession |
| Keychain Services | Almacenamiento seguro de tokens |
| Xcode 26 | IDE y build system |

- **Repositorio**: [`Rural-Code-Labs/ommadawn-ios`](https://github.com/Rural-Code-Labs/ommadawn-ios)
- **Bundle id**: `com.ruralcodelabs.ommadawn`
- **Plataformas**: iOS — iPhone/iPad (deployment target 26.5)
- **Organización**: [Rural-Code-Labs](https://github.com/Rural-Code-Labs) (la misma que la API)

---

## Estructura del proyecto

La **capa de red vive en un paquete Swift local aparte** (`OmmadawnAPI`), separada
de la app. Contiene el cliente generado y la lógica de sesión reutilizable; la app
solo la consume.

```
ommadawn/
├── OmmadawnAPI/                       # 📦 Paquete local: capa de red
│   ├── Package.swift
│   └── Sources/OmmadawnAPI/
│       ├── openapi.json               # contrato "vendorizado" (snapshot)
│       ├── openapi-generator-config.yaml
│       ├── APIClient.swift            # entornos + fábrica del cliente
│       ├── TokenStore.swift           # tokens en Keychain (actor)
│       ├── TokenRefresher.swift       # renovación coordinada (single-flight)
│       ├── AuthMiddleware.swift       # Bearer + (401 → refresh → reintento)
│       ├── AvatarUpload.swift         # sube el avatar con el Content-Type real
│       ├── ImageUpload.swift          # sube imágenes de edición (mismo patrón)
│       ├── DateTranscoding.swift      # fechas ISO8601 con microsegundos
│       └── Models.swift               # alias de conveniencia (User)
│
├── ommadawn.xcodeproj/
├── ommadawn/                          # 📱 App
│   ├── ommadawnApp.swift              # @main · posee la AuthSession
│   ├── ContentView.swift              # router según el estado de sesión
│   ├── RootTabView.swift              # shell tras el login: cabecera común + TabView
│   ├── LoginView.swift
│   ├── Auth/
│   │   ├── AuthSession.swift          # @Observable: sesión + perfil + avatar + logout
│   │   └── RegisterView.swift
│   ├── Account/
│   │   ├── AccountMenu.swift          # menú desplegable (editar perfil, cerrar sesión)
│   │   ├── AccountProfileView.swift   # hoja de perfil: avatar + datos editables
│   │   ├── AccountAvatarView.swift    # avatar circular reutilizable
│   │   └── User+Presentation.swift    # displayName, avatarURL
│   ├── Admin/                         # gestión de administradores (solo superadmin)
│   │   ├── AdminStore.swift
│   │   └── AdminUsersView.swift
│   ├── Settings/                      # ajustes de la app
│   │   └── SettingsView.swift         # apariencia sincronizada con servidor + admin
│   ├── Discography/                   # Fase 4: catálogo + edición para admins · Fase 6: colecciones
│   │   ├── DiscographyStore.swift
│   │   ├── ReleaseListView.swift
│   │   ├── ReleaseDetailView.swift
│   │   ├── ReleaseEditView.swift       # crear/editar/eliminar disco (solo admins)
│   │   ├── EditionEditView.swift       # crear/editar/eliminar edición + tracklist + imágenes
│   │   ├── Release+Presentation.swift
│   │   ├── CollectionListView.swift    # listado + CollectionFormView (crear/editar)
│   │   ├── CollectionDetailView.swift
│   │   └── CollectionTagPickerView.swift
│   ├── Forum/                          # Fase 7: foro de discusión (subforos + hilos + comentarios)
│   │   ├── ForumStore.swift
│   │   ├── Forum+Presentation.swift
│   │   ├── ForumThreadListView.swift
│   │   ├── ForumThreadDetailView.swift
│   │   └── ForumThreadComposeView.swift
│   ├── Shared/                        # componentes reutilizables entre dominios
│   │   ├── Country.swift              # modelo Country + lista ISO 3166-1 + "EU"
│   │   ├── CountryPickerView.swift    # hoja de selección de país con frecuentes + buscador
│   │   ├── MarkdownTextEditor.swift   # UITextView + MarkdownEditorController + MarkdownEditorSection
│   │   └── MarkdownCheatsheetView.swift # referencia rápida de sintaxis Markdown
│   ├── Design/
│   │   ├── BrandMark.swift            # el logo "O" en Didot Italic como vista reutilizable
│   │   ├── AppTheme.swift             # apariencia + extensión para sincronizar con API
│   │   └── AboutView.swift            # pantalla "Acerca de" con logo Rural Code Labs
│   └── Assets.xcassets/               # AppIcon, BrandGray, AccentColor, RuralCodeLabsLogo
│
├── ommadawnTests/                     # Tests unitarios (Swift Testing)
└── ommadawnUITests/                   # Tests de UI
```

> El código del cliente generado (`Client.swift`, `Types.swift`) **no se versiona**:
> lo produce el build plugin en cada compilación a partir de `openapi.json`.

---

## Relación con la API

La app **no tiene lógica de dominio propia ni base de datos**: consume la API REST
`ommadawn-api`, que es la fuente de verdad del catálogo.

| | |
|---|---|
| Repo de la API | `github.com/Rural-Code-Labs/ommadawn-api` |
| Carpeta local | `~/development/python/ommadawn-api` |
| Base URL (desarrollo) | `http://localhost:8000/api/v1` |
| Contrato OpenAPI | `http://localhost:8000/openapi.json` |
| Docs interactivas | `http://localhost:8000/docs` (Swagger) · `/redoc` |

**Contract-first.** El contrato de la API (OpenAPI) es la frontera entre los dos
proyectos. En vez de escribir a mano modelos y llamadas, generamos el cliente con
`swift-openapi-generator` a partir del `openapi.json`. Ventajas:

- Los tipos de request/response de la app **siempre coinciden** con la API.
- Un cambio en la API que rompa el contrato **se detecta al compilar**, no en runtime.
- Menos código de red que mantener a mano.

La API versiona desde el día 1 (`/api/v1/...`): un cambio incompatible será una
versión nueva, no romper la existente.

### Regenerar el cliente cuando cambie la API

El `openapi.json` es un **snapshot** dentro del repo. Cuando la API cambie, se
refresca a mano y se recompila:

```bash
curl -s http://127.0.0.1:8000/openapi.json \
  -o OmmadawnAPI/Sources/OmmadawnAPI/openapi.json
```

Notas de la generación:

- **`serverURL` = solo el origen** (`http://127.0.0.1:8000`). Las rutas del contrato
  ya incluyen `/api/v1/...`, así que ese prefijo **no** va en la base URL.
- La **primera compilación en Xcode** pide confiar en el plugin
  (`OpenAPIGenerator` → *Trust & Enable*). Por CLI se usa
  `xcodebuild ... -skipPackagePluginValidation`.
- **Resuelto:** el campo opcional `full_name` se arregló del lado de la API
  (`app/core/openapi.py` post-procesa el esquema: "anulable" → "opcional"). Cualquier
  campo opcional futuro queda cubierto igual, sin hacer nada en la app.

---

## Autenticación

Implementada de punta a punta. La API maneja **dos tokens** y la app respeta ese flujo:

| | Access token | Refresh token |
|---|---|---|
| Qué es | JWT firmado | Cadena opaca aleatoria |
| Duración | Corta (~15 min) | Larga (~30 días), **rotativo** |
| Uso | `Authorization: Bearer <token>` | Renovar el access token |

Cómo está montado:

- **`TokenStore`** (actor): guarda el par de tokens en **un único item** del Keychain
  (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, nunca `UserDefaults`). Un solo item
  porque el refresh **rota** y hay que actualizarlo de forma atómica.
- **`AuthMiddleware`**: añade el `Bearer`, renueva **proactivamente** si está a punto de
  caducar (usando `expires_in`), y ante un `401` renueva y **reintenta una vez**.
  Va por lista de **exclusión** (health/login/register/refresh) → todo lo demás queda
  protegido por defecto. `TokenRefresher` coordina las renovaciones con *single-flight*
  (dos renovaciones a la vez invalidarían la familia de tokens).
- **`AuthSession`** (`@Observable`): estado `loading / signedOut / signedIn`; la vista
  raíz enruta según él. Expone `restore` (arranque), `logIn`, `register` (con
  auto-login) y `logOut`.
- **Logout instantáneo**: cierra en local primero (sin esperar a la red) y revoca en el
  servidor en segundo plano.
- Login por **usuario _o_ email** (campo `username_or_email`).
- **Login con Google**: SDK oficial `GoogleSignIn-iOS`. La app solo obtiene el ID token
  de Google; se lo pasa a la API (`POST /auth/google`), que lo verifica y devuelve el
  mismo par access/refresh que el login por contraseña — a partir de ahí no hay ninguna
  diferencia entre una sesión u otra. Conflicto de email (alguien entra con Google usando
  un email que ya tiene cuenta con contraseña) responde `409` con un código distinguible
  y la app lo traduce en un mensaje con sugerencia, sin auto-vincular ni duplicar cuentas.
  Al darse de alta por Google, el username se genera al azar (`user-1234`) y se puede
  editar **una sola vez** desde el perfil — después queda fijo, igual que cualquier otro.
- **Vincular/desvincular Google desde el perfil**: botón "Conectar con Google" o
  "Desconectar Google" en `AccountProfileView` (`POST`/`DELETE /auth/me/google`,
  autenticado). No se puede vincular una cuenta de Google ya enlazada a otro usuario
  (`409`), ni desvincular si es la única forma de entrar (`409`). Los errores de esta
  sección se muestran con `.alert` (modal), no como texto en la pantalla: un texto
  pegado a la sección puede quedar fuera de vista si el usuario no hace scroll tras
  pulsar el botón.
- **Cambiar / agregar / quitar contraseña**: un único endpoint (`POST /auth/me/password`)
  cambia la contraseña o la pone por primera vez (cuenta creada solo por Google) —
  `current_password` solo hace falta si la cuenta ya tenía una. `DELETE
  /auth/me/password` la quita, rechazando con `409` si no hay Google vinculado (se
  quedaría sin forma de entrar). `UserRead` expone `has_password` (igual que
  `has_google`), así que la app sabe de antemano qué campos/botones mostrar: el botón
  dice "Cambiar contraseña" o "Agregar contraseña" según corresponda, y "Quitar
  contraseña" solo aparece si hay contraseña **y** Google vinculado a la vez.
- **Verificación de correo**: "soft" — no bloquea nada de la app, solo un aviso.
  Código de 6 dígitos (no enlace) enviado por email, caduca en 2h, máximo 5 intentos
  fallidos en una ventana móvil de 24h compartida entre códigos. Cuentas creadas por
  Google llegan ya verificadas (el ID token lo confirma). En el perfil, una pastilla
  "Sin verificar" junto al email abre una hoja para pedir/confirmar el código — no se
  envía nada automáticamente al abrirla, para no invalidar un código que la persona ya
  tuviera sin leer.
- **Recuperar contraseña**: mismo patrón de código de 6 dígitos, sin sesión (es justo
  el caso que resuelve esto). La API no revela si una cuenta existe — responde igual
  pida quien pida un código, exista o no el email/usuario — y da el mismo error tanto
  si el código es incorrecto como si la cuenta no existe, para que el endpoint no
  sirva para averiguar qué cuentas están registradas. Al confirmar con el código y la
  contraseña nueva, la API loguea directamente (mismo `TokenPair` que `/auth/login`),
  sin pedir un segundo login. Enlace "¿Olvidaste tu contraseña?" en `LoginView`.

Endpoints de auth: `register`, `login`, `refresh`, `logout`, `google`, `me` (`GET`/`PATCH`),
`me/avatar` (`POST`/`DELETE`), `me/google` (`POST`/`DELETE`), `me/password`
(`POST`/`DELETE`), `verify-email/request`, `verify-email/confirm`,
`password-reset/request`, `password-reset/confirm`, `users` (`GET`, superadmin),
`users/{id}` (`PATCH`, superadmin).

---

## Cuenta, perfil y administración

La cabecera de la app (fija por encima del `TabView`, no se mueve al navegar) tiene el
**avatar circular a la izquierda** (despliega `AccountMenu`) y el **engranaje a la
derecha** (abre `SettingsView`). Desde ahí:

- **AccountMenu**: solo "Editar perfil" y "Cerrar sesión". Las opciones de apariencia y
  administración se movieron a Ajustes.
- **Perfil** (`AccountProfileView`): avatar (`PhotosPicker` para subir/cambiar, o
  quitarlo) y datos — `username` y email como filas bloqueadas (con 🔒), con la "G" de
  Google junto al email si la cuenta la tiene vinculada; campos editables con etiqueta
  visible (nombre, país, ciudad, fecha de nacimiento) — vía `PATCH /auth/me`. Un campo
  se puede rellenar pero no vaciar desde aquí todavía (el PATCH de la API es parcial: un
  campo ausente no se toca). **Excepción**: si el username es el generado al azar de un
  alta por Google (`username_is_default`), la fila pasa a ser un campo editable con una
  nota — se puede cambiar una única vez, después queda fijo igual que el resto.
- **Ajustes** (`SettingsView`): selector de apariencia (Sistema/Claro/Oscuro)
  sincronizado con `theme_preference` del servidor — al guardar se hace `PATCH /auth/me`
  y al restaurar sesión se aplica la preferencia del servidor. Solo superadmins ven
  además el acceso a "Administrar usuarios".
- **Administración** (`AdminUsersView`, solo superadmin): lista de usuarios con
  interruptor para promover/degradar a administrador. Nombrar superadmins sigue siendo
  solo por base de datos.
- **Detalle técnico**: el contrato declara el fichero del avatar como
  `contentMediaType: application/octet-stream`, y el cliente generado usaría ese valor
  literal como `Content-Type` del *part* multipart — pero la API valida el tipo real de
  la imagen contra ese header. `AvatarUpload.swift` (en `OmmadawnAPI`) construye el
  *part* a mano con el `Content-Type` real, detectado por los primeros bytes del
  fichero.

---

## Identidad visual

Marca propia de estilo caligráfico, montada como un pequeño sistema reutilizable y
**sin empaquetar fuentes** (usa las que ya trae iOS):

- **Logo**: la inicial **"O" de Didot Italic** (misma familia y estilo que el wordmark),
  en carboncillo. Vive en `Design/BrandMark.swift` y es la misma imagen que el icono de
  la app.
- **Wordmark**: *Ommadawn* en **Didot Italic**.
- **Logo de marca**: Rural Code Labs (claro/oscuro), usado en la pantalla "Acerca de".
- **Color de marca**: `BrandGray` en el catálogo, adaptativo a claro/oscuro.
- **Estilo general**: *minimal del sistema* — el resto de la UI se apoya en colores y
  materiales nativos de iOS.

---

## Puesta en marcha

Requisitos: **Xcode 26** o superior (macOS).

```bash
# Abrir el proyecto
open ommadawn.xcodeproj
```

Compilar y ejecutar desde Xcode (⌘R) sobre un simulador de iPhone, o por línea de comandos:

```bash
# Build (el simulador de referencia es iPhone 17; en Xcode 26 ya no existe iPhone 16)
xcodebuild -scheme ommadawn -destination 'platform=iOS Simulator,name=iPhone 17' build

# Tests
xcodebuild -scheme ommadawn -destination 'platform=iOS Simulator,name=iPhone 17' test
```

> La primera vez, Xcode pedirá **confiar en el plugin** de generación
> (`OpenAPIGenerator`). Por CLI, añade `-skipPackagePluginValidation`.

### Levantar la API en local

La app necesita la API corriendo. En `~/development/python/ommadawn-api`:

```bash
source .venv/bin/activate
docker compose up -d            # PostgreSQL local
alembic upgrade head            # esquema al día
uvicorn app.main:app --reload   # http://localhost:8000
```

Comprueba que responde: `http://localhost:8000/docs`.

> **Simulador y `localhost`.** El simulador de iOS comparte red con el Mac, así
> que `http://localhost:8000` funciona sin más. En **dispositivo físico** habrá que
> usar la IP del Mac en la red local (y ajustar ATS para permitir HTTP en desarrollo).

---

## Plan por fases

Se construye por fases pequeñas; cada una se cierra (y se entiende) antes de la
siguiente. La app va **por detrás de la API**: cada dominio se consume cuando la
API ya lo expone.

| Fase | Contenido | Estado |
|---|---|---|
| **1 — Esqueleto** | Proyecto Xcode iOS SwiftUI que arranca. | ✅ Hecha |
| **2 — Capa de red** | Paquete `OmmadawnAPI` con `swift-openapi-generator`, cliente base y configuración de entorno. | ✅ Hecha |
| **3 — Autenticación** | Registro/login, tokens en Keychain, renovación automática (reactiva + proactiva), logout. | ✅ Hecha |
| **Identidad visual** | Logo, wordmark e icono propios. | ✅ Hecha |
| **4 — Discografía** | Listado (grid/lista, filtro, orden) y detalle con tracklist; cabecera con avatar y engranaje de ajustes; perfil editable con avatar y país; apariencia sincronizada con el servidor; gestión de administradores; pantalla "Acerca de"; edición completa del catálogo para admins (descripción/créditos/notas en Markdown con preview, imágenes con ↑↓, filtros multi-selección con banderas, sello discográfico seleccionable). | ✅ Hecha |
| **5 — Mejoras de autenticación** | Login con Google (SDK oficial, conflicto de email sin auto-vincular), username editable una sola vez cuando lo asigna Google, vincular/desvincular Google desde el perfil, cambiar/agregar/quitar contraseña, verificación de correo y recuperación de contraseña — estas dos últimas por código de 6 dígitos, no por enlace. | ✅ Hecha |
| **6 — Colecciones de ediciones** | Agrupar ediciones de discos distintos bajo un nombre común (ej. "Remasterizaciones HDCD"), no cajas físicas de un mismo álbum (eso ya es un disco normal). Segmented Discos/Colecciones en la pestaña Discografía, tags al editar una edición (buscar o crear), enlace inverso "Parte de: X", gestión completa para admins. | ✅ Hecha |
| **7 — Foro / contribuciones** | Foro de discusión atado al catálogo (discos, ediciones, discografía en general, y futuros dominios); solo un admin aplica los cambios. Hilos y comentarios en Markdown (mismo editor de la Fase 4). Organizado en subforos (hoy solo "Discusiones"). Pestaña Inicio con casos abiertos. | 🚧 En marcha |
| **8 — Valoración de discos** | Puntuar discos/ediciones. | Pendiente |
| **9 — Colección personal** | Cada usuario registra las ediciones que tiene, con estado de disco y funda (escala Discogs). | Pendiente |
| **10 — Conciertos** | Giras, fechas, setlists. | Pendiente |
| **11 — Libros** | Bibliografía. | Pendiente |
| **Siguientes** | Otras secciones a acordar. | Pendiente |
