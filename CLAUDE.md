# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Qué es este proyecto

`ommadawn` (app) es el **cliente móvil** de la API [`ommadawn-api`](#relación-con-la-api-hermana):
un catálogo de la obra de **Mike Oldfield** (discografía, conciertos, libros y otras
secciones). La app **no tiene lógica de dominio ni base de datos propia**: presenta lo
que sirve la API, que es la fuente de verdad.

Primero **iOS**. El proyecto es multiplataforma (iOS, macOS, visionOS); Android será en
el futuro con otra base de código.

**Contexto de trabajo — importante:**
- Es un proyecto **de aprendizaje**, pero con intención de **publicarse** y ser usado por
  gente real. Las decisiones deben ser sólidas, no solo "que funcione".
- **No se trabaja en modo vibe coding.** Prioriza que el usuario entienda *qué* se hace y
  *por qué*. Explica las decisiones; no generes grandes cantidades de código de golpe sin
  contexto. Mejor ir despacio y con criterio.

---

## Estado actual

> **Este archivo (y el `README`) son la "memoria" del repo: mantenlos actualizados
> según avanza el proyecto.** Si cambia el estado, las decisiones o el flujo de trabajo,
> actualiza aquí antes de dar una tarea por cerrada.

- **Repositorio**: `github.com/Rural-Code-Labs/ommadawn-ios` (organización
  *Rural-Code-Labs*, la misma que la API, no la cuenta personal). Carpeta local:
  `~/development/swift/ommadawn`. El repo va con sufijo **`-ios`** (habrá un futuro
  cliente Android aparte); la carpeta y el target Xcode se llaman `ommadawn`.
- **Estado**: **scaffold recién creado** (plantilla por defecto de Xcode). `ContentView`
  es todavía el "Hello, world!" del template. No hay capa de red ni pantallas propias.
- **Bundle id**: `com.ruralcodelabs.ommadawn`. Deployment target 26.5 (iOS/macOS/visionOS),
  Swift 5, Xcode 26.
- **Siguiente paso**: **Fase 2 — capa de red** (integrar `swift-openapi-generator` con el
  `openapi.json` de la API). Ver plan por fases abajo.

---

## Relación con la API hermana

La app consume la API REST `ommadawn-api`. **El contrato OpenAPI es la frontera** entre
ambos proyectos y hay que respetarlo como tal.

| | |
|---|---|
| Repo | `github.com/Rural-Code-Labs/ommadawn-api` |
| Carpeta local | `~/development/python/ommadawn-api` |
| Base URL (dev) | `http://localhost:8000/api/v1` |
| Contrato OpenAPI | `http://localhost:8000/openapi.json` |
| Docs | `http://localhost:8000/docs` (Swagger) · `/redoc` |

- La API tiene su propio `CLAUDE.md` y `README.md` en su carpeta: **consúltalos** para
  conocer endpoints, contratos y estado antes de tocar la capa de red de la app.
- La API **versiona desde el día 1** (`/api/v1/...`). Un cambio incompatible será
  `/api/v2`, nunca romper lo existente. La app depende de ese contrato estable.
- La API va **por delante** de la app: cada dominio se consume en la app cuando la API ya
  lo expone (la API va por la Fase 5 — discografía).

### Cómo se genera el cliente (contract-first)

Decisión tomada: usar **`swift-openapi-generator`** para generar el cliente HTTP tipado a
partir del `openapi.json`, en vez de escribir modelos `Codable` y llamadas a mano.

- Los tipos de request/response **siempre coinciden** con la API.
- Un cambio que rompa el contrato **se detecta al compilar**.
- Al regenerar (cuando cambie la API), no re-escribir a mano el código generado.

### Autenticación — reglas que la app debe cumplir

La API maneja **access token (JWT, ~15 min)** + **refresh token (opaco, ~30 días, con
rotación)**. Implicaciones para la app:

- Enviar `Authorization: Bearer <access token>` en las peticiones protegidas.
- Ante un `401`, renovar con `POST /api/v1/auth/refresh` y reintentar **una vez**.
- **Rotación**: cada refresh devuelve un par nuevo → guardar **siempre el último** refresh
  token y descartar el anterior.
- Tokens en el **Keychain**, nunca en `UserDefaults`.
- `logout` (`POST /api/v1/auth/logout`) revoca el refresh token en el servidor.
- Endpoints de auth: `register`, `login`, `refresh`, `logout`, `me`.

---

## Estructura del proyecto

```
ommadawn/
├── ommadawn.xcodeproj/          # Proyecto Xcode (multiplataforma)
├── ommadawn/                    # Código de la app
│   ├── ommadawnApp.swift        # @main · App / Scene (punto de entrada)
│   ├── ContentView.swift        # Vista raíz (aún el template de Xcode)
│   └── Assets.xcassets/         # Iconos y colores
├── ommadawnTests/               # Tests unitarios (Swift Testing)
└── ommadawnUITests/             # Tests de UI (XCUITest)
```

A medida que avancen las fases, la idea es organizar por **features/dominios** (auth,
discography, concerts…) con una capa de red compartida y el cliente OpenAPI generado
aparte. La estructura concreta se decidirá al llegar a cada fase, sin sobre-diseñar antes
de tiempo.

---

## Comandos

```bash
# Abrir en Xcode
open ommadawn.xcodeproj

# Build (simulador iOS)
xcodebuild -scheme ommadawn -destination 'platform=iOS Simulator,name=iPhone 16' build

# Tests
xcodebuild -scheme ommadawn -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Para trabajar contra la API en local, levantarla en `~/development/python/ommadawn-api`
(`docker compose up -d` → `alembic upgrade head` → `uvicorn app.main:app --reload`) y
comprobar `http://localhost:8000/docs`.

> **`localhost` desde el simulador** funciona (comparte red con el Mac). En **dispositivo
> físico** hay que usar la IP del Mac en la LAN y ajustar ATS para permitir HTTP en dev.

---

## Plan por fases

Fases **pequeñas y entendibles**; cada una se cierra antes de la siguiente. La app va por
detrás de la API: cada dominio se consume cuando la API ya lo expone.

| Fase | Contenido | Estado |
|---|---|---|
| **1 — Esqueleto** | Proyecto Xcode multiplataforma SwiftUI que arranca (plantilla). | ✅ Hecha |
| **2 — Capa de red** | Integrar `swift-openapi-generator` con `openapi.json`, cliente base, config de base URL por entorno. | ⏭️ Siguiente |
| **3 — Autenticación** | Registro/login, tokens en Keychain, renovación automática con refresh + reintento. | Pendiente |
| **4 — Discografía** | Listado y detalle de discos (consume la Fase 5 de la API). | Pendiente |
| **5 — Conciertos** | Giras, fechas, setlists. | Pendiente |
| **6 — Libros** | Bibliografía. | Pendiente |
| **Siguientes** | Otras secciones a acordar con el usuario. | Pendiente |
