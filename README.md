# Ommadawn (app)

App móvil que cataloga la obra de **Mike Oldfield**: discografía (álbumes de
estudio, recopilatorios, singles, directos, bootlegs…), conciertos, libros y
otras secciones. Es el **cliente** de la API [`ommadawn-api`](#relación-con-la-api):
todo el contenido lo sirve esa API y la app lo presenta.

> Proyecto de aprendizaje, pero construido con criterio y con la intención de
> publicarse de verdad. Se avanza en **fases pequeñas y entendibles**,
> priorizando el *por qué* de cada decisión sobre la velocidad.

Primero **iOS**; el proyecto es multiplataforma (iOS, macOS, visionOS) y Android
queda para el futuro con otra base de código.

---

## Stack

| Tecnología | Función |
|---|---|
| Swift 5 | Lenguaje |
| SwiftUI | UI declarativa |
| Swift Concurrency (`async/await`) | Llamadas de red y trabajo asíncrono |
| [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) | Genera el cliente HTTP tipado desde el `openapi.json` de la API |
| Xcode 26 | IDE y build system |

- **Repositorio**: [`Rural-Code-Labs/ommadawn-ios`](https://github.com/Rural-Code-Labs/ommadawn-ios)
- **Bundle id**: `com.ruralcodelabs.ommadawn`
- **Plataformas**: iOS · macOS · visionOS (deployment target 26.5)
- **Organización**: [Rural-Code-Labs](https://github.com/Rural-Code-Labs) (misma
  que la API, no la cuenta personal)

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
versión nueva, no romper la existente. La app depende de ese contrato estable.

### Autenticación

La API maneja **dos tokens** y la app debe respetar ese flujo:

| | Access token | Refresh token |
|---|---|---|
| Qué es | JWT firmado | Cadena opaca aleatoria |
| Duración | Corta (~15 min) | Larga (~30 días) |
| Uso | `Authorization: Bearer <token>` en cada petición | Renovar el access token |

- El access token caduca pronto: cuando la API responde `401`, la app renueva con
  el refresh token (`POST /api/v1/auth/refresh`) y reintenta.
- **Rotación**: cada renovación devuelve un par nuevo; hay que **guardar siempre
  el último** refresh token. En iOS los tokens van al **Keychain**, nunca a
  `UserDefaults`.
- `logout` revoca el refresh token en el servidor.

Endpoints de auth disponibles: `register`, `login`, `refresh`, `logout`, `me`
(ver README de la API para el detalle).

---

## Estructura del proyecto

```
ommadawn/
├── ommadawn.xcodeproj/          # Proyecto Xcode
├── ommadawn/                    # Código de la app
│   ├── ommadawnApp.swift        # @main · punto de entrada (App / Scene)
│   ├── ContentView.swift        # Vista raíz (por ahora el template de Xcode)
│   └── Assets.xcassets/         # Iconos, colores
├── ommadawnTests/               # Tests unitarios (Swift Testing)
└── ommadawnUITests/             # Tests de UI
```

> Estado actual: **scaffold recién creado**. Aún es la plantilla por defecto de
> Xcode (una vista "Hello, world!"). La capa de red, el cliente generado y las
> pantallas de catálogo se irán añadiendo por fases.

---

## Puesta en marcha

Requisitos: **Xcode 26** o superior (macOS).

```bash
# Abrir el proyecto
open ommadawn.xcodeproj
```

Compilar y ejecutar desde Xcode (⌘R) sobre un simulador de iPhone, o por línea
de comandos:

```bash
# Build
xcodebuild -scheme ommadawn -destination 'platform=iOS Simulator,name=iPhone 16' build

# Tests
xcodebuild -scheme ommadawn -destination 'platform=iOS Simulator,name=iPhone 16' test
```

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
> que `http://localhost:8000` funciona. En **dispositivo físico** habrá que usar
> la IP del Mac en la red local (y configurar ATS para permitir HTTP en desarrollo).

---

## Plan por fases

Se construye por fases pequeñas; cada una se cierra (y se entiende) antes de la
siguiente. La app va **por detrás de la API**: cada dominio se consume cuando la
API ya lo expone.

| Fase | Contenido | Estado |
|---|---|---|
| **1 — Esqueleto** | Proyecto Xcode multiplataforma SwiftUI que arranca (plantilla). | ✅ Hecha |
| **2 — Capa de red** | Integrar `swift-openapi-generator` con el `openapi.json`, cliente base y configuración de entorno (base URL). | ⏭️ Siguiente |
| **3 — Autenticación** | Pantallas de registro/login, guardado de tokens en Keychain, renovación automática con el refresh token. | Pendiente |
| **4 — Discografía** | Listado y detalle de discos (consume la Fase 5 de la API). | Pendiente |
| **5 — Conciertos** | Giras, fechas, setlists. | Pendiente |
| **6 — Libros** | Bibliografía. | Pendiente |
| **Siguientes** | Otras secciones a acordar. | Pendiente |
