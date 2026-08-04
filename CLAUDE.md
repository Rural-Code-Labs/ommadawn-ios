# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Qué es este proyecto

`ommadawn` (app) es el **cliente móvil** de la API [`ommadawn-api`](#relación-con-la-api-hermana):
un catálogo de la obra de **Mike Oldfield** (discografía, conciertos, libros y otras
secciones). La app **no tiene lógica de dominio ni base de datos propia**: presenta lo
que sirve la API, que es la fuente de verdad.

**iOS** (iPhone/iPad). Se descartó dar soporte a macOS/visionOS (27 jul 2026): el target
llegó a compilar para macOS, pero además de las adaptaciones de UI (`navigationBarTitleDisplayMode`
no existe en AppKit) hacía falta un entitlement de Keychain que exige un perfil de
aprovisionamiento de equipo real — complejidad que no compensa para una app de aprendizaje
que ya tiene claro que es, ante todo, un cliente de iPhone/iPad. Android será en el futuro
con otra base de código.

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
- **Estado**: **Fase 3 hecha** (autenticación completa: registro, login por
  `username_or_email`, sesión persistente en Keychain, renovación automática — reactiva
  ante `401` y **proactiva** usando `expires_in` — y logout) y **Fase 4 en marcha**
  (discografía: listado con grid/lista/filtro/orden y detalle con tracklist, **solo
  lectura**; cabecera común de la app con avatar a la izquierda y engranaje de ajustes a
  la derecha; perfil de usuario editable con avatar; gestión de administradores para
  superadmins; pantalla de Ajustes con apariencia sincronizada con el servidor). Ver plan
  abajo.
- **Bundle id**: `com.ruralcodelabs.ommadawn`. Deployment target 26.5 (solo iOS: iPhone/iPad),
  Swift 5, Xcode 26.
- **Edición de catálogo para admins (Fase 4, hecha en 3 capas, 30 jul 2026)**:
  1. **Capa 1 — Release CRUD**: `ReleaseEditView` (crear/editar título y tipo), eliminar
     release con `confirmationDialog`. Menú ⋯ en toolbar del detalle, solo visible a admins.
  2. **Capa 2 — Edition CRUD + tracklist**: `EditionEditView` (crear/editar edición con
     metadatos completos y tracklist), eliminar edición. Los temas usan `EditableTrack`
     (modelo local con `durationText` "M:SS") y se envían como array completo en el PATCH.
     Nota: `.environment(\.editMode, .constant(.active))` bloquea taps en Buttons — se usan
     botones ⊖ inline en cada fila en vez de `.onDelete`.
  3. **Capa 3 — Imágenes de edición**: `ImageUpload.swift` en `OmmadawnAPI`: multipart a mano
     con MIME real (mismo patrón que `AvatarUpload`). El caso 413 en el contrato generado se
     llama `.contentTooLarge`. La UI de imágenes se integró en `EditionEditView` (ver abajo).
- **Lista de ediciones en detalle (30 jul 2026)**: el `Picker` segmentado se reemplazó por
  una lista de filas (`EditionRow`) con miniatura de portada, nombre, formato · año · sello
  y checkmark en la edición seleccionada. Al tocar una fila se actualiza el detalle.
- **Selector de entorno de API (1 ago 2026, solo `#if DEBUG`)**: `APIEnvironment` tiene
  dos casos (`development` → `http://127.0.0.1:8000`, `preproduction` →
  `https://api.pre.ommadawn.es`), persiste en `UserDefaults` y tiene `displayName`.
  `AuthSession.switchEnvironment(_:)` persiste el nuevo entorno, cierra sesión y recrea
  `refresher` y `client`. El selector aparece en `SettingsView` (sección "Entorno",
  Picker inline con confirmación de alerta) y en `LoginView` (badge de antena al pie del
  formulario con `confirmationDialog`, para poder cambiar antes de autenticarse). En
  builds de Release no aparece nada.
- **UX del detalle de release (2 ago 2026)**:
  - **Badge de ediciones en portada**: pildora flotante en la esquina inferior derecha
    de la imagen de portada con icono `rectangle.stack.fill` y el número de ediciones
    (solo si hay más de una). Color `.tint` para visibilidad en modo claro y oscuro.
  - **Hoja de ediciones con filtros**: `EditionListSheet` gana filtros multi-selección
    (Tipo, Año, Sello) con icono relleno cuando hay filtro activo y botón "Restablecer".
    Las secciones de filtro se muestran incluso cuando solo hay un valor único.
  - **Visor de imágenes corregido**: `ImageViewerView` reescrito con `ScrollViewReader` +
    `HStack` (no `LazyHStack`) y `proxy.scrollTo` diferido en `DispatchQueue.main.async`
    para abrir siempre en la imagen tapeada, no en la primera. `fullScreenCover(item:)`
    con `ImageViewerItem: Identifiable` captura el índice de forma atómica en el tap.
- **Engranaje de ajustes solo para admins (2 ago 2026)**: el botón de engranaje en
  `AppHeaderBar` se envuelve en `if user.is_admin`. El selector de apariencia se mueve
  del `SettingsView` al `AccountMenu` (sección "Apariencia" con `Picker` + `.onChange`
  que sincroniza con el servidor).
- **Banderas de países y selector de país (2 ago 2026)**:
  - **`Shared/Country.swift`**: modelo `Country` (código ISO 3166-1 alpha-2, nombre en
    español vía `Locale(identifier: "es")`, bandera emoji). La lista se genera con
    `NSLocale.isoCountryCodes` (solo países soberanos reales) más una `extraCodes`
    whitelist para códigos supranacionales que la API acepta: actualmente `["EU"]`
    (Unión Europea). El campo `country` de la API valida `^[A-Z]{2}$`; la validación de
    negocio del servidor admite los extras. `String.flagEmoji` convierte alpha-2 →
    Regional Indicator emoji.
  - **`Shared/CountryPickerView.swift`**: hoja reutilizable con sección "Frecuentes"
    (GB, DE, US, JP, NL, FR, IT, AU, CA, ES) siempre visible, buscador permanente en la
    cabecera de la lista (no `.searchable` de iOS, que en iOS 26 se mueve abajo) y
    botón "Quitar país" cuando hay selección.
  - El `TextField` de país en `EditionEditView` y `AccountProfileView` se reemplaza por
    un `Button` que abre `CountryPickerView` como hoja. El campo `country` de
    `EditionPayload` pasa de `String` a `String?`.
  - Las ediciones muestran la bandera del país en `ReleaseDetailView` (en `editionMeta`
    y en el título de `EditionRow` cuando no hay `edition_name`).
  - `EditionListSheet` incluye filtro multi-selección por país (además de Tipo, Año, Sello).
    Las banderas aparecen como overlay 20pt en la esquina inferior derecha de cada miniatura.
- **Imágenes de edición integradas en `EditionEditView` (4 ago 2026)**:
  - La hoja `EditionImagesView` se elimina; la sección "Imágenes" se muestra directamente
    en el formulario de edición (solo en modo editar). Subir/eliminar son llamadas inmediatas
    a la API (sin esperar a "Guardar"), coexisten con el botón "Guardar" de metadatos.
  - **Unicidad de portada/contraportada**: el `Picker` de tipo oculta "Portada" / "Contraportada"
    si ya existe una imagen de ese tipo; `adjustImageType` cambia el selector a "Otra"
    automáticamente cuando un tipo se llena.
  - **Ordenación de imágenes**: botones ↑↓ en cada fila (`chevron.up` / `chevron.down`).
    Llaman a `PATCH .../images/{id}/position` (`ImageMoveRequest { direction: "up"|"down" }`),
    que devuelve el array completo ya ordenado (`[ImageRead]`); `DiscographyStore.moveEditionImage`
    devuelve `[ReleaseImage]`. Las imágenes se muestran ordenadas por `position`.
- **Editor Markdown reutilizable (4 ago 2026)**:
  - **`Shared/MarkdownTextEditor.swift`**: `UITextView` envuelto en `UIViewRepresentable` +
    `MarkdownEditorController` (`@Observable @MainActor`) que mantiene referencia débil al
    `UITextView` y expone `wrapSelection(with:)`, `insertLink()`, `insertListItem()` y
    `insertBlockquote()`. El controlador se crea con `@State` en la vista padre (no
    `@StateObject` — `@Observable` ya gestiona la identidad estable).
  - **`Shared/MarkdownEditorSection`**: `Section` de SwiftUI lista para usar en un `Form`.
    Toolbar con 5 botones: **N** (negrita `**`), *C* (cursiva `_`), enlace (`[texto](url)`),
    lista (`- `), cita (`> `), más `?` para abrir el cheatsheet.
  - **`Shared/MarkdownCheatsheetView.swift`**: hoja de referencia rápida con la sintaxis
    Markdown más común (negrita, cursiva, enlace, títulos, lista, cita, código, separador).
  - **`ReleaseEditView`**: gana sección "Descripción" con `MarkdownEditorSection` (altura 220pt).
    `DiscographyStore.createRelease/updateRelease` pasan `description: String?`.
    openapi.json actualizado: `ReleaseRead/Create/Update` incluyen `description`.
  - **`EditionEditView`**: los campos `credits` y `notes` (antes `TextField`) usan ahora
    `MarkdownEditorSection`. Controladores independientes por campo; cheatsheet compartido.
- **Detalle de lectura completo (4 ago 2026, rediseñado el mismo día)**:
  - **`description` del disco**: sección desplegable junto al título — el chevron ∨/∧ aparece a la derecha del `Text` del título (en un `HStack`). Al expandir muestra el contenido completo renderizado con `DynamicMarkdownWebView` (altura adaptada al contenido vía JS `document.body.scrollHeight`). Si el disco no tiene descripción, el chevron no aparece.
  - **Metadatos de edición como tabla**: `editionMeta` usa un `Grid` con dos columnas (etiqueta secundaria / valor), mostrando País, Sello, Publicación (fecha completa localizada en español vía `DateFormatter`), Formato y Cat. Solo aparecen los campos informados.
  - **`credits` y `notes` de la edición**: secciones desplegables con cabecera `headline` + chevron ∨/∧, mismo patrón collapsible. Sin resumen de 3 líneas: o se ve todo o no se ve nada. Renderizadas con `DynamicMarkdownWebView`.
  - Los campos ausentes (`nil` o vacíos) no se renderizan en ningún caso.
- **Preview Markdown en el editor y renderizado compartido (4 ago 2026)**:
  - **Botón de preview (👁)** en la toolbar de `MarkdownEditorSection`: al pulsarlo abre `MarkdownPreviewSheet` (WKWebView) con el contenido actual del campo. El estado de preview (`showingPreview`, `previewTitle`, `previewText`) vive en `MarkdownEditorController` (referencia estable en el padre) y el `.sheet` se ancla al `Form` del caller (`EditionEditView`, `ReleaseEditView`) — necesario porque un `.sheet` anclado a una celda de Form/List dentro de otra hoja puede ser reseteado por SwiftUI cuando el teclado se descarta y la jerarquía se recrea.
  - **Código de renderizado Markdown centralizado en `MarkdownTextEditor.swift`**: `MarkdownWebView` (para hojas modales), `DynamicMarkdownWebView` (para incrustar en `ScrollView`, altura adaptada con `WKNavigationDelegate`), `MarkdownPreviewSheet` (hoja compartida con ✕), `markdownStyledHTML` (con padding 16px, para hojas), `markdownInlineHTML` (sin padding, para incrustar), `markdownToHTML` + `inlineMd` (conversor bloque/inline Markdown→HTML). `ReleaseDetailView` ya no duplica este código.

### Backlog de mejoras acordadas (Fase 4)

Leyenda: 🟢 solo app · 🔴 requiere cambio en la API primero

| # | Mejora | Requiere API |
|---|---|---|
| 6 | **Nombre de edición en el detalle**: mostrar el `edition_name` de la edición activa junto (o bajo) el título del disco cuando está informado — p.ej. "Tubular Bells · Deluxe Edition". Ahora solo se ve el título del release. | 🟢 Solo app |
| 7 | **Créditos por pista**: cada track puede tener sus propios créditos (ej. "Guitarra: Mike Oldfield"). Requiere nuevo campo en el modelo de track de la API y UI en `EditionEditView` para editarlos y en `ReleaseDetailView` para mostrarlos. | 🔴 API: campo `credits: String?` en `Track`, incluido en el contrato |
| 1 | **Rediseño de vista de discografía**: portada completa en detalle (ocupa más espacio, ediciones en hoja o sección expandible), galería con primera foto grande y resto en miniaturas. ~~Países con bandera~~: ✅ hecho (2 ago 2026). | 🟢 Solo app |
| 2 | **Sello seleccionable**: poder elegir un sello ya existente o crear uno nuevo al editar una edición. Necesita un endpoint de sellos en la API. | 🔴 API: endpoint `/labels` (listado + creación) |
| 5 | ~~**Ordenar imágenes "Otras" de una edición**~~: ✅ hecho (4 ago 2026) — botones ↑↓ en `EditionEditView`, API con `position` + `PATCH .../images/{id}/position`. | ✅ |
| 3 | **Contribuciones de usuarios normales**: cualquier usuario puede proponer cambios; un admin los aprueba/rechaza. Necesita modelo de contribuciones en la API y pantalla de revisión en la app. | 🔴 API: modelo `Contribution`, endpoints de envío y revisión |
| 4 | **Colección personal**: cada usuario puede marcar qué ediciones tiene en su colección con el estado del disco y la funda (p. ej. Mint / Near Mint / Very Good+ / Very Good / Good / Fair / Poor — escala Discogs). Implica una vista de colección propia y un botón en el detalle de edición. | 🔴 API: modelo `CollectionEntry` (user, edition, disc_condition, sleeve_condition, notas opcionales), endpoints `GET/POST /collection`, `PATCH/DELETE /collection/{id}` |
| 8 | **Colecciones de ediciones** *(idea a largo plazo)*: agrupar varias ediciones bajo un nombre de colección (p. ej. "Deluxe Edition Box Set" agrupa la edición original + el bonus disc + el DVD). Una colección es una lista ordenada de ediciones con nombre propio. Útil para cajas y ediciones multi-disco. | 🔴 API: modelo `EditionCollection` (name, ordered list of edition IDs), endpoints CRUD |

### Backlog de mejoras de autenticación

| # | Mejora | Requiere API |
|---|---|---|
| A1 | **Cambiar contraseña**: formulario en `AccountProfileView` (o hoja aparte) con contraseña actual + nueva + confirmación. | 🔴 API: `POST /auth/me/password` con `current_password` + `new_password` |
| A2 | **Recuperar contraseña** ("¿Olvidaste tu contraseña?"): flujo de reset por email — el usuario pide el enlace, recibe un correo con un token de un solo uso y establece una nueva contraseña. | 🔴 API: `POST /auth/password-reset/request` + `POST /auth/password-reset/confirm`; requiere servicio de email en el servidor |
| A3 | **Verificación de correo**: al registrarse, el usuario recibe un email de confirmación; la cuenta queda pendiente hasta que verifica. | 🔴 API: campo `email_verified` en el usuario, `POST /auth/verify-email/request` + `POST /auth/verify-email/confirm`; requiere servicio de email |

> A2 y A3 comparten infraestructura de email en la API (proveedor SMTP o servicio transaccional). Tiene sentido implementarlas juntas en el lado del servidor.

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

**Cómo está montado (Fase 2):**

- La capa de red vive en un **paquete Swift local aparte**, `OmmadawnAPI/` (no en el target
  de la app). Contiene `Package.swift`, el contrato **vendorizado** `openapi.json`, la config
  `openapi-generator-config.yaml` (`generate: [types, client]`, `accessModifier: public`) y el
  poco código a mano: `APIClient.swift` (`APIEnvironment` + `Client(environment:)`).
- El código del cliente se genera con el **build plugin** en cada compilación (no se comitea).
  Transporte: `swift-openapi-urlsession`. `.build/` y `.swiftpm/` están en `.gitignore`.
- **Regenerar tras un cambio en la API**: `curl -s http://127.0.0.1:8000/openapi.json -o
  OmmadawnAPI/Sources/OmmadawnAPI/openapi.json` y recompilar. El contrato es un snapshot: se
  refresca a mano cuando la API cambia.
- **`serverURL` = solo origen** (`http://127.0.0.1:8000`): las rutas del contrato ya incluyen
  `/api/v1/...`, así que **no** se pone el prefijo en la base URL.
- **Primera compilación en Xcode**: pide confiar en el plugin (`OpenAPIGenerator` →
  "Trust & Enable"). Por CLI se usa `xcodebuild ... -skipPackagePluginValidation`.
- El paquete local está cableado a mano en el `.xcodeproj` (referencia local + dependencia de
  producto en el target `ommadawn`). Simulador de referencia: `iPhone 17` (en Xcode 26 ya no
  existe `iPhone 16`).

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

### Cómo está montada (Fase 3)

- **`TokenStore`** (`OmmadawnAPI`, actor): guarda el par de tokens en **un solo item** del
  Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). Un item porque el refresh rota
  y hay que actualizarlo de forma atómica. Logout borra todo por `service`.
- **`AuthMiddleware`** (`OmmadawnAPI`): inyecta `Authorization: Bearer` y, ante un `401`,
  renueva y **reintenta una vez**. Lista de **exclusión** (health/login/register/refresh);
  todo lo demás va protegido por defecto. `TokenRefresher` (actor) coordina las renovaciones
  con *single-flight* (la API rota el refresh; dos renovaciones a la vez lo invalidarían).
- **`AuthSession`** (app, `@Observable @MainActor`): dueño único del cliente autenticado y del
  refresher. Estado `loading/signedOut/signedIn(User)`; `ContentView` enruta según él.
  Expone `restore` (arranque), `logIn`, `register` (con auto-login) y `logOut`.
- **Logout**: cierra en local **primero** (Keychain + estado, sin red) y revoca en el
  servidor en segundo plano *best-effort*. Las acciones del usuario no esperan a la red.
- **Fechas**: `DateTranscoder` propio porque la API (Python) emite microsegundos, que el
  decodificador ISO8601 por defecto rechaza.

> **Resuelto:** `full_name` llegó a faltar en el modelo generado (el generador descartaba
> el `anyOf` con `null` que emite Pydantic para los opcionales). Se arregló del lado de la
> API (`app/core/openapi.py` post-procesa el esquema: "anulable" → "opcional", ver el
> `CLAUDE.md` de `ommadawn-api`). Cualquier campo opcional futuro queda cubierto igual, sin
> hacer nada en la app.

---

## Discografía (Fase 4)

Primera entrega en `main`, **solo lectura** (crear/editar queda para cuando haya UI de
admin). Consume `/api/v1/discography/*` de la API (`Release` → `Edition` → `Track`/`Image`).

- **`Discography/DiscographyStore`**: envuelve el `Client` de `AuthSession` (expuesto como
  `let client` para reutilizarlo, en vez de crear una sesión HTTP aparte) con
  `fetchReleases(type:)` y `fetchRelease(id:)`. `struct` sin estado propio, no
  `@Observable`: no hay nada aquí que una vista necesite observar.
- **`ReleaseListView`**: grid o lista (toggle), filtro por tipo y orden por año/nombre
  (por defecto año) — ambos en un `Menu` en la toolbar, a la altura del título.
  *Pull-to-refresh* con `.refreshable`. **Ojo**: `.task(id:)` (carga inicial) y
  `.refreshable` pueden llamar a `load()` casi a la vez; `load()` comparte una única
  `Task` en curso para que la segunda llamada se una a la primera en vez de disparar
  otra petición (si no, la API cancela una de las dos: `NSURLErrorCancelled`).
- **`ReleaseDetailView`**: recibe el `Release` ya completo desde el listado (el contrato
  ya anida ediciones/temas/imágenes en `GET /releases`, no hace falta pedirlo aparte);
  el *pull-to-refresh* del detalle es lo único que vuelve a llamar a la API
  (`fetchRelease(id:)`), por si algo cambió desde que se cargó la lista.
- **`Release+Presentation.swift`**: helpers de presentación sobre los tipos generados
  (`displayEdition`, `coverURL`, `ReleaseType.displayName` en español) — viven en el
  target de la app, no en `OmmadawnAPI`, porque son decisiones de cómo se muestra el
  catálogo, no del contrato en sí.
- **`RootTabView`**: shell de navegación tras el login. `TabView` con pestañas
  Discografía / Tours (esta última un placeholder hasta la Fase 5). Por encima del
  `TabView` vive `AppHeaderBar`, una cabecera **común a toda la app** (no es el
  `navigationBar` de ninguna pestaña, así que no se mueve al navegar dentro de ellas):
  `AccountMenu` (avatar circular) superpuesto a la **izquierda**, wordmark "Ommadawn"
  centrado, y botón engranaje de ajustes superpuesto a la **derecha** (abre
  `SettingsView`). Las vistas raíz de cada pestaña no ponen su propio `navigationTitle`
  (la pestaña activa ya dice la sección); las vistas de detalle sí, y aparece debajo de
  la cabecera como si continuara el título de la app.
- Los controles de filtro/orden (con dirección ascendente/descendente) y cambio de
  vista de `ReleaseListView` son un *capsule* flotante cerca del borde inferior
  derecho, no toolbar items.

**No se llama `Image` a secas** el alias de `ImageRead` en `Models.swift` (es
`ReleaseImage`): colisionaría con `SwiftUI.Image` en cualquier vista que importe ambos
módulos.

---

## Cuenta: menú, perfil, ajustes y administración (Fase 4)

`AccountMenu` cuelga del avatar circular en el lado **izquierdo** de `AppHeaderBar`.
Contiene solo dos acciones: **"Editar perfil"** (abre `AccountProfileView`) y
**"Cerrar sesión"** (destructivo). Las opciones de apariencia y administración se
movieron al engranaje de ajustes (botón derecho de la cabecera → `SettingsView`).

- **`Settings/SettingsView`**: pantalla de ajustes — selector de apariencia
  (Sistema/Claro/Oscuro, estilo `.inline`, sincronizado con `theme_preference` del
  servidor vía `PATCH /auth/me`) y, solo si `is_super_admin`, acceso a "Administrar
  usuarios". La sincronización va en ambas direcciones: al arrancar/hacer login,
  `AuthSession.applyTheme(from:)` aplica la preferencia guardada en el servidor al
  `UserDefaults` que lee `@AppStorage("appearance")`.
- **`Design/AppTheme`**: gana una extensión con `apiValue`
  (`Components.Schemas.ThemePreference`) e `init(from:)` para convertir entre el enum
  local y el tipo generado del contrato, sin acoplar la capa de red al enum de UI.
- **`Account/User+Presentation.swift`**: `displayName` (`full_name` si lo hay, si no
  `username`) y `avatarURL` (`URL?` desde `avatar_url`) como extensiones de `User` —
  presentación, no contrato, mismo criterio que `Release+Presentation.swift`.
- **`Account/AccountAvatarView`**: el avatar en un círculo (o el símbolo genérico de
  persona si no hay foto). Se usa tanto en el icono pequeño de `AccountMenu` como en el
  preview grande de `AccountProfileView`.
- **`Account/AccountProfileView`**: hoja de perfil — avatar (`PhotosPicker` para
  subir/cambiar, botón para quitar) y sección "Datos" con el **`username` no editable**
  (primera fila, `LabeledContent`) seguido de los campos editables con etiqueta visible
  (nombre, país, ciudad, fecha de nacimiento) vía `PATCH /auth/me`. Los campos usan
  `LabeledContent` + `TextField` alineado a la derecha para que la etiqueta sea siempre
  visible, incluso cuando el campo tiene contenido. Lee el usuario **en vivo** desde
  `AuthSession` para que el avatar se refresque solo; los campos del formulario se
  siembran **una vez** al aparecer para no perder lo que la persona esté escribiendo.
  - **Limitación conocida**: un campo se puede rellenar pero no "vaciar" desde aquí (un
    campo vacío no se envía, por cómo funciona el PATCH parcial de la API).
- **`AuthSession`**: gana `updateProfile` (con `themePreference`), `uploadAvatar` y
  `deleteAvatar`. Las tres actualizan `state` con el `UserRead` que devuelve la API.
  `applyTheme(from:)` (privado) sincroniza `UserDefaults` al restaurar sesión, hacer
  login y guardar perfil.
- **`OmmadawnAPI/Sources/OmmadawnAPI/AvatarUpload.swift`**: sube el avatar construyendo
  el *part* multipart **a mano**, no con el case `.file` que genera el plugin. El
  contrato declara el fichero como `contentMediaType: application/octet-stream`, y el
  generador usa ESE valor literal como `Content-Type` del *part* — pero la API valida
  el tipo real de la imagen (`image/jpeg`/`png`/`webp`) contra ese header, así que
  subiendo por el case generado la API respondería 422 siempre, fuera cual fuera la
  imagen. Se construye el *part* con el case `.undocumented` (`MultipartRawPart`) para
  poner el `Content-Type` real, detectado por los primeros bytes del fichero (magic
  numbers) ya que `PhotosPicker` no expone el tipo MIME de forma directa.
- **`Admin/AdminStore`** y **`Admin/AdminUsersView`**: gestión de administradores,
  mismo patrón que `DiscographyStore` (envuelve el `Client` de `AuthSession`). Lista
  usuarios (`GET /auth/users`) y promueve/degrada a admin (`PATCH /auth/users/{id}`) —
  ambos endpoints exigen **superadministrador** del lado de la API; el `is_super_admin`
  que gatea la entrada del menú en la app es solo UI, no la única barrera. No se puede
  tocar `is_super_admin` desde la app: nombrar un superadmin sigue siendo solo por BD.

---

## Estructura del proyecto

```
ommadawn/
├── ommadawn.xcodeproj/          # Proyecto Xcode (iOS: iPhone/iPad)
├── ommadawn/                    # Código de la app
│   ├── ommadawnApp.swift        # @main · posee la AuthSession
│   ├── ContentView.swift        # Vista raíz: enruta según el estado de sesión
│   ├── RootTabView.swift        # Shell tras el login: cabecera común + TabView
│   ├── LoginView.swift
│   ├── Auth/
│   │   ├── AuthSession.swift    # @Observable: sesión + perfil + avatar + logout
│   │   └── RegisterView.swift
│   ├── Account/
│   │   ├── AccountMenu.swift          # Menú desplegable (nombre, apariencia, admin, logout)
│   │   ├── AccountProfileView.swift   # Hoja de perfil: avatar + datos editables
│   │   ├── AccountAvatarView.swift    # Avatar circular reutilizable
│   │   └── User+Presentation.swift    # displayName, avatarURL
│   ├── Admin/                    # Gestión de administradores (solo superadmin)
│   │   ├── AdminStore.swift
│   │   └── AdminUsersView.swift
│   ├── Settings/                 # Ajustes de la app
│   │   └── SettingsView.swift    # apariencia (sincronizada con servidor) + admin
│   ├── Discography/              # Fase 4: catálogo + edición para admins
│   │   ├── DiscographyStore.swift
│   │   ├── ReleaseListView.swift
│   │   ├── ReleaseDetailView.swift
│   │   ├── ReleaseEditView.swift        # crear/editar/eliminar disco (solo admins)
│   │   ├── EditionEditView.swift        # crear/editar/eliminar edición + tracklist + imágenes
│   │   └── Release+Presentation.swift
│   ├── Shared/                   # Componentes reutilizables entre dominios
│   │   ├── Country.swift              # modelo Country + NSLocale.isoCountryCodes + extraCodes
│   │   ├── CountryPickerView.swift    # hoja de selección de país con frecuentes + buscador
│   │   ├── MarkdownTextEditor.swift   # UITextView + MarkdownEditorController + MarkdownEditorSection
│   │   └── MarkdownCheatsheetView.swift # referencia rápida de sintaxis Markdown
│   ├── Design/
│   │   ├── BrandMark.swift      # el logo "O" en Didot Italic como vista reutilizable
│   │   ├── AppTheme.swift       # AppTheme + extensión apiValue/init(from:) para sincronizar con API
│   │   └── AboutView.swift      # pantalla "Acerca de" con logo Rural Code Labs
│   └── Assets.xcassets/         # AppIcon, BrandGray, AccentColor, RuralCodeLabsLogo
├── ommadawnTests/               # Tests unitarios (Swift Testing)
└── ommadawnUITests/             # Tests de UI (XCUITest)
```

Organizado por **features/dominios** (auth, account, discography…), cada uno con sus
propias vistas. La capa de red compartida y el cliente OpenAPI generado viven aparte, en
el paquete `OmmadawnAPI/` (ver arriba). La estructura de los dominios que faltan
(conciertos, libros…) se decidirá al llegar a esa fase, sin sobre-diseñar antes de tiempo.

---

## Comandos

```bash
# Abrir en Xcode
open ommadawn.xcodeproj

# Build (simulador iOS)
xcodebuild -scheme ommadawn -destination 'platform=iOS Simulator,name=iPhone 17' build

# Tests
xcodebuild -scheme ommadawn -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Para trabajar contra la API en local, levantarla en `~/development/python/ommadawn-api`
(`docker compose up -d` → `alembic upgrade head` → `uvicorn app.main:app --reload`) y
comprobar `http://localhost:8000/docs`.

> **`localhost` desde el simulador** funciona (comparte red con el Mac). En **dispositivo
> físico** hay que usar la IP del Mac en la LAN y ajustar ATS para permitir HTTP en dev.

---

## Skills de Swift/iOS (solo este proyecto)

En `.claude/skills/` hay un **subconjunto curado** de skills de especialización en
Swift/iOS, instaladas **solo en este repo** (no en la config global). Se activan solas por
su `description` cuando la tarea encaja, y el cuerpo/`references` solo se cargan al usarse.
Apuntan a **iOS 26+ / Swift 6.x** (compatibles hacia atrás salvo que se indique), que es el
target del proyecto.

> ⚠️ **No están versionadas.** `.claude/skills/` está en `.gitignore`: este repo es
> **público** y las skills tienen licencia PolyForm Perimeter (source-available, no
> redistribuir). Viven solo en local; hay que **reinstalarlas** al clonar el repo o
> montar el proyecto desde cero (ver *Reinstalar* al final de esta sección).

Instaladas (16), elegidas para un **cliente REST en SwiftUI**:

| Skill | Para qué |
|---|---|
| `ios-networking` | URLSession async/await, cliente de API, reintentos, WebSocket |
| `swift-concurrency` | `async/await`, actores, `Sendable`, Swift 6 concurrency |
| `swift-codable` | (De)codificación JSON, estrategias de claves |
| `swift-security` | Keychain, almacenamiento de tokens/secretos (clave para auth) |
| `authentication` | OAuth, passkeys, flujos de login |
| `swiftui-navigation` | NavigationStack/SplitView, sheets, tabs, deep links |
| `swiftui-patterns` | Observation, arquitectura de vistas, ownership |
| `swiftui-layout-components` | Listas, scroll, componentes de layout |
| `swiftui-performance` | Rendimiento de listas/feeds, Instruments |
| `swiftui-liquid-glass` | Diseño Liquid Glass de iOS 26 |
| `swift-architecture` | Selección de patrón, migración a Observation |
| `swift-language` | Refactors modernos, interoperabilidad |
| `swift-api-design-guidelines` | Nombrado y diseño de API idiomático |
| `swift-formatstyle` | Formateo/parseo de fechas, números, localización |
| `swift-testing` | Framework Swift Testing (`@Test`, `#expect`) |
| `ios-simulator` | Arrancar/gestionar el simulador, rutas, push, privacidad |

- **Origen**: [`dpearson2699/swift-ios-skills`](https://github.com/dpearson2699/swift-ios-skills)
  (el repo trae ~86 skills, una por framework de Apple). Se copiaron solo `SKILL.md` +
  `references/` de las relevantes (sin `evals/`).
- **Licencia**: PolyForm Perimeter License 1.0.0 (© 2025 dpearson2699) — source-available
  con restricciones. Por eso **no se suben** a este repo público.
- **Añadir más**: copiar la carpeta de la skill deseada desde ese repo a `.claude/skills/`.

### Reinstalar (proyecto desde cero / nuevo clon)

Como no están en git, hay que volver a instalarlas en local. Desde la raíz del repo:

```bash
git clone --depth 1 https://github.com/dpearson2699/swift-ios-skills.git /tmp/swift-ios-skills
mkdir -p .claude/skills
for s in ios-networking swift-concurrency swift-codable swift-security \
         swiftui-navigation swiftui-patterns swiftui-layout-components swiftui-performance \
         swift-architecture swift-testing swiftui-liquid-glass swift-formatstyle \
         authentication swift-language swift-api-design-guidelines ios-simulator; do
  mkdir -p ".claude/skills/$s"
  cp "/tmp/swift-ios-skills/skills/$s/SKILL.md" ".claude/skills/$s/"
  [ -d "/tmp/swift-ios-skills/skills/$s/references" ] && \
    cp -R "/tmp/swift-ios-skills/skills/$s/references" ".claude/skills/$s/"
done
rm -rf /tmp/swift-ios-skills
```

Tras instalarlas, **reiniciar la sesión** de Claude Code para que las detecte. Ojo con el
word-splitting: el bucle de arriba asume `bash`; en `zsh` interactivo funciona igual porque
la lista va explícita en el `for` (no en una variable).

---

## Plan por fases

Fases **pequeñas y entendibles**; cada una se cierra antes de la siguiente. La app va por
detrás de la API: cada dominio se consume cuando la API ya lo expone.

| Fase | Contenido | Estado |
|---|---|---|
| **1 — Esqueleto** | Proyecto Xcode iOS SwiftUI que arranca (plantilla). | ✅ Hecha |
| **2 — Capa de red** | Paquete `OmmadawnAPI` con `swift-openapi-generator` + `openapi.json`, cliente base, config de base URL por entorno. Probado con `GET /health`. | ✅ Hecha |
| **3 — Autenticación** | Registro/login, tokens en Keychain, renovación automática (reactiva + proactiva) con refresh + reintento. | ✅ Hecha |
| **4 — Discografía** | Listado y detalle de discos (consume la Fase 5 de la API). | 🚧 En marcha — listado/detalle ✅, cabecera ✅, AccountMenu simplificado ✅, SettingsView con apariencia sincronizada ✅, perfil con avatar ✅, gestión de admins ✅, AboutView ✅, edición de catálogo para admins (Release/Edition CRUD + tracklist + imágenes) ✅, lista de ediciones con miniaturas ✅, selector de entorno debug ✅, detalle de lectura completo con secciones desplegables y renderizado WKWebView ✅, botón de preview en editor Markdown ✅ |
| **5 — Conciertos** | Giras, fechas, setlists. | Pendiente |
| **6 — Libros** | Bibliografía. | Pendiente |
| **Siguientes** | Otras secciones a acordar con el usuario. | Pendiente |
