# Ommadawn (app)

App móvil que cataloga **el universo sonoro de Mike Oldfield**: discografía
(álbumes de estudio, recopilatorios, singles, directos, bootlegs…), conciertos,
libros y otras secciones. Es el **cliente** de la API
[`ommadawn-api`](#relación-con-la-api): todo el contenido lo sirve esa API y la
app lo presenta.

> Proyecto de aprendizaje, pero construido con criterio y con la intención de
> publicarse de verdad. Se avanza en **fases pequeñas y entendibles**,
> priorizando el *por qué* de cada decisión sobre la velocidad.

Primero **iOS**; el objetivo es multiplataforma (iOS, macOS, visionOS) — el target de
Xcode ya lo es de nombre, pero el soporte real de macOS/visionOS todavía está pendiente
de trabajo (hay APIs de UIKit-only colándose en las vistas nuevas). Android queda para
el futuro con otra base de código.

---

## Estado

- ✅ **Fase 1 — Esqueleto**: proyecto Xcode multiplataforma que arranca.
- ✅ **Fase 2 — Capa de red**: cliente HTTP tipado generado desde el contrato.
- ✅ **Fase 3 — Autenticación**: registro, login, tokens en Keychain, renovación
  automática (reactiva ante `401` y proactiva con `expires_in`) y logout.
- ✅ **Identidad visual**: logo, wordmark e icono propios.
- 🚧 **Fase 4 — Discografía**: primera entrega — listado (grid/lista, filtro, orden) y
  detalle con tracklist, **solo lectura**. Pendiente: menú de Cuenta como desplegable,
  soporte real de macOS y edición de discos para administradores.

Ver el [plan por fases](#plan-por-fases) completo abajo.

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
- **Plataformas**: iOS · macOS · visionOS (deployment target 26.5)
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
│       ├── DateTranscoding.swift      # fechas ISO8601 con microsegundos
│       └── Models.swift               # alias de conveniencia (User)
│
├── ommadawn.xcodeproj/
├── ommadawn/                          # 📱 App
│   ├── ommadawnApp.swift              # @main · posee la AuthSession
│   ├── ContentView.swift              # router según el estado de sesión
│   ├── RootTabView.swift              # shell tras el login: TabView Discografía/Cuenta
│   ├── LoginView.swift
│   ├── Auth/
│   │   ├── AuthSession.swift          # @Observable: estado + login/registro/logout
│   │   └── RegisterView.swift
│   ├── Account/
│   │   └── AccountView.swift          # saludo, cerrar sesión, apariencia
│   ├── Discography/                   # Fase 4: catálogo (solo lectura)
│   │   ├── DiscographyStore.swift
│   │   ├── ReleaseListView.swift
│   │   ├── ReleaseDetailView.swift
│   │   └── Release+Presentation.swift
│   ├── Design/
│   │   ├── BrandMark.swift            # el logo "O" como vista reutilizable
│   │   └── AppTheme.swift             # apariencia (Sistema/Claro/Oscuro)
│   └── Assets.xcassets/               # AppIcon, BrandGray, AccentColor
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

Endpoints de auth: `register`, `login`, `refresh`, `logout`, `me`.

---

## Identidad visual

Marca propia de estilo caligráfico, montada como un pequeño sistema reutilizable y
**sin empaquetar fuentes** (usa las que ya trae iOS):

- **Logo**: la inicial **"O" de Didot** (alto contraste) inclinada, en carboncillo.
  Vive en `Design/BrandMark.swift` y es la misma imagen que el icono de la app.
- **Wordmark**: *Ommadawn* en **Snell Roundhand** (script).
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
| **1 — Esqueleto** | Proyecto Xcode multiplataforma SwiftUI que arranca. | ✅ Hecha |
| **2 — Capa de red** | Paquete `OmmadawnAPI` con `swift-openapi-generator`, cliente base y configuración de entorno. | ✅ Hecha |
| **3 — Autenticación** | Registro/login, tokens en Keychain, renovación automática (reactiva + proactiva), logout. | ✅ Hecha |
| **Identidad visual** | Logo, wordmark e icono propios. | ✅ Hecha |
| **4 — Discografía** | Listado y detalle de discos. | 🚧 En marcha (lectura ✅; pendiente: menú de Cuenta, macOS real, edición admin) |
| **5 — Conciertos** | Giras, fechas, setlists. | Pendiente |
| **6 — Libros** | Bibliografía. | Pendiente |
| **Siguientes** | Otras secciones a acordar. | Pendiente |
