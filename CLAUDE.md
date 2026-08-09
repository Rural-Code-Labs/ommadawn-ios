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
  ante `401` y **proactiva** usando `expires_in` — y logout), **Fase 4 hecha** (discografía
  completa: listado con grid/lista/filtro/orden, detalle con tracklist, cabecera común de
  la app, perfil de usuario editable con avatar, gestión de administradores, edición
  completa del catálogo para admins, sello seleccionable), **Fase 5 hecha** (login con
  Google: alta/login básico, conflicto de email, nombre de usuario editable una sola vez
  cuando lo asignó Google, vincular/desvincular Google desde el perfil, cambiar/agregar/
  quitar contraseña, verificación de correo por código, y recuperación de contraseña por
  código), **Fase 6 hecha** (colecciones de ediciones: agrupar ediciones de discos
  distintos bajo un nombre, ej. "Remasterizaciones HDCD") y **Fase 7 en marcha** (foro
  de discusión atado al catálogo, organizado en subforos — hoy solo "Discusiones" —,
  textos en Markdown con el editor de la Fase 4; modelo y endpoints de la API listos,
  hilos en el detalle de disco/edición en marcha; falta pestaña Inicio con casos
  abiertos — ver más abajo). Ver plan abajo.
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
- **Grabaciones: edición directa, borrado huérfano e indicador de uso (6 ago 2026)**:
  - **Edición directa de grabaciones vinculadas**: `TrackEditRow` pasa de tener los campos de solo lectura cuando hay `recording_id` (modo "linked") a mostrarlos siempre editables. Al guardar la edición, `EditionEditView.save()` hace un **diff con `originalTracks`** (snapshot inmutable del estado al abrir): si el título, duración o créditos de una grabación vinculada cambiaron, llama a `PATCH /discography/recordings/{id}` (`DiscographyStore.updateRecording`) antes de actualizar la edición. Las grabaciones recién vinculadas (no presentes en `originalTracks`) se saltan porque ya tienen los datos correctos.
  - **Borrado automático de grabaciones huérfanas**: al pulsar ⊖ en una fila del tracklist, si el track tiene `recording_id` se añade a `pendingDeleteRecordingIDs`. Tras un `save()` exitoso, se intenta `DELETE /discography/recordings/{id}` (`DiscographyStore.deleteRecording`) en cada ID acumulado — best-effort (`try?`); la API devuelve `409` si la grabación sigue en uso en otra edición (se conserva silenciosamente) o `204` si era huérfana (se elimina).
  - **Cápsula visual "linked"**: el indicador de grabación vinculada en `TrackEditRow` se muestra como una cápsula pequeña con el icono 🔗 y la ✕ en rojo (`.foregroundStyle(.red)`). La ✕ desvincula (pone `recording_id = nil`); la fila pasa a modo "libre" y el siguiente guardado crea una grabación nueva en vez de parchear la existente.
  - **Indicador de uso en el buscador**: `RecordingSearchSheet` muestra bajo cada resultado una línea en cursiva secundaria con el release y edición donde se usa esa grabación (ej. "Tubular Bells · 1973"). Requirió añadir `usages: [RecordingUsageRead]` (default `[]`) a `RecordingRead` en la API. El nuevo schema `RecordingUsageRead` tiene `release_id`, `release_title`, `edition_id` (required) y `edition_name`, `release_date` (optional). El helper `usageLabel(_:)` en `EditionEditView` formatea la primera entrada. Contrato `openapi.json` actualizado tras el cambio en la API.

## Login con Google (Fase 5, 6 ago 2026)

Implementado de punta a punta: SDK oficial `GoogleSignIn-iOS` 9.2.0 vía SPM, endpoints
`POST /auth/google` (login/alta) y `POST`/`DELETE /auth/me/google` (vincular/desvincular
desde el perfil) en la API, nombre de usuario editable una sola vez cuando lo puso
Google. Probado en simulador y en dispositivo físico contra pre-producción.

- **SDK y configuración**: dependencia remota `GoogleSignIn-iOS` añadida a mano al
  `.pbxproj` (mismo patrón que la referencia local de `OmmadawnAPI`). `Info.plist`
  propio (`ommadawn/Info.plist`) con `CFBundleURLTypes` (el `REVERSED_CLIENT_ID`),
  fusionado con el Info.plist auto-generado vía `INFOPLIST_FILE` — hace falta una
  **excepción de membresía** en el grupo sincronizado (`PBXFileSystemSynchronized
  BuildFileExceptionSet`) para que ese fichero no se copie también como recurso (si
  no, Xcode lo procesa dos veces y el build falla con "Multiple commands produce").
  `Auth/GoogleAuthConfig.swift` centraliza los dos Client ID (iOS y Web/servidor).
  `ommadawnApp.swift` configura `GIDSignIn.sharedInstance` al arrancar y añade
  `.onOpenURL` para el callback del navegador embebido.
- **Dos Client ID, un solo propósito**: el iOS Client ID identifica la app ante Google;
  el Web Client ID se pasa como `serverClientID` en `GIDConfiguration` y es lo que la
  API usa como audiencia (`aud`) al verificar el ID token — así, cuando llegue un
  cliente Android, reutiliza la misma audiencia sin tocar la API.
- **`AuthSession.signInWithGoogle(idToken:)`**: llama a `POST /auth/google`, guarda el
  mismo `TokenPair` que `logIn`/`refresh` y sigue el mismo camino final — la sesión no
  distingue después si vino de Google o de contraseña. `GoogleSignInError` mapea
  401 (token inválido) / 403 (cuenta desactivada) / 409 (`email_conflict`) / 422.
- **`LoginView`**: el botón "Continuar con Google" lanza `GIDSignIn.sharedInstance
  .signIn(withPresenting:)`, saca el `idToken` del resultado y llama a
  `signInWithGoogle`. Cancelar el flujo (`GIDSignInError.canceled`) no muestra error:
  es una acción deliberada del usuario, no un fallo.
- **Middleware de auth**: `google_login_api_v1_auth_google_post` tuvo que añadirse a
  la lista de exclusión de `AuthMiddleware` (`OmmadawnAPI/Sources/OmmadawnAPI/
  AuthMiddleware.swift`) — es un endpoint de login, no lleva `Bearer`, y sin la
  exclusión el middleware fallaba con `notAuthenticated` antes de llegar a hacer la
  petición (no había sesión previa de la que sacar un token).
- **Conflicto de email**: si el email de Google ya existe en una cuenta con contraseña
  sin Google vinculado, la API responde `409` con `detail: "email_conflict"` (código,
  no frase) y la app lo traduce a "Ya tienes una cuenta con ese email. Entra con tu
  contraseña y vincula Google desde tu perfil." Sin auto-vinculación ni crear duplicados.
- **`GoogleMark.swift`** (`Shared/`): la "G" en degradado, reutilizable con tamaño
  configurable — antes vivía duplicada dentro de `LoginView`, ahora también se usa en
  el perfil.
- **`has_google` en el perfil**: `UserRead` expone si la cuenta tiene Google vinculado.
  `AccountProfileView` muestra "Usuario" y "Email" como filas bloqueadas (con 🔒) en
  vez de mezcladas con los campos editables, y la "G" pequeña junto al email cuando
  `has_google` es `true`.
- **Username editable una sola vez**: al darse de alta por Google, la API genera un
  username **aleatorio** (`user-1234`, no derivado del email) y marca
  `username_is_default = true`. Mientras ese flag siga activo, `AccountProfileView`
  muestra el campo "Usuario" como un `TextField` editable con una nota ("Google te
  asignó este nombre. Puedes cambiarlo, pero solo una vez."); en cuanto se guarda un
  cambio real, el servidor fija el username para siempre (`PATCH /auth/me` responde
  `409` con `detail: "username_already_set"` en cualquier intento posterior — código
  distinguible, no frase). La app solo manda `username` en el PATCH si de verdad
  cambió respecto al valor cargado, para no gastar el único cambio por accidente al
  guardar otro campo del formulario. **Cuentas creadas antes de este cambio** se
  quedan con `username_is_default = false` (la migración no las marca retroactivamente
  como editables) — es el comportamiento esperado, no un bug.
- **Vincular/desvincular Google desde el perfil**: nueva sección "Cuenta de Google" en
  `AccountProfileView` — "Conectar con Google" (mismo flujo `GIDSignIn` que el login,
  pero llama a `AuthSession.linkGoogleAccount(idToken:)` → `POST /auth/me/google`,
  autenticado, no es un login) o "Desconectar Google" (`confirmationDialog` de aviso →
  `AuthSession.unlinkGoogleAccount()` → `DELETE /auth/me/google`).
  - **`google_already_linked`** (409 al vincular): esa cuenta de Google ya pertenece a
    otro usuario — no se puede compartir una misma cuenta de Google entre dos usuarios.
  - **Errores como `alert`, no como texto en la sección**: la primera versión ponía el
    mensaje de error como `Text` dentro de la `Section` "Cuenta de Google", pero si el
    botón queda arriba y el usuario no hace scroll tras pulsarlo, ese texto no se ve —
    parece que la acción no hizo nada. Se cambió a `.alert` (modal, centrado, no
    depende de la posición de scroll) con un `Binding` derivado de
    `googleErrorMessage != nil`.
  - `UIApplication.topViewController` se extrajo a `Shared/UIApplication+
    TopViewController.swift`: lo necesitan tanto `LoginView` (login) como
    `AccountProfileView` (vinculación) para presentar el navegador embebido del SDK.
- **Cambiar / agregar / quitar contraseña** (5.4, 6 ago 2026): un único endpoint,
  `POST /auth/me/password`, cubre tanto cambiarla (cuenta con contraseña) como ponerla
  por primera vez (cuenta solo-Google) — `current_password` es opcional a nivel de
  schema y el servicio decide si hace falta según si `hashed_password` ya existe.
  `DELETE /auth/me/password` es el espejo: la quita, y rechaza con `409`
  (`detail: "password_only_access"`) si no hay Google vinculado (se quedaría sin
  ninguna forma de entrar) — mismo criterio que `google_only_access` al desvincular
  Google.
  - **`has_password` en el perfil**: igual que `has_google`, `UserRead` expone si la
    cuenta tiene contraseña. Con esto ya no hace falta adivinar nada por UI: el botón
    "Quitar contraseña" solo aparece si `has_password && has_google`, y
    `ChangePasswordView` oculta el campo "Contraseña actual" por completo (no lo deja
    vacío con una nota) cuando `hasPassword` es `false`.
  - **`ChangePasswordView.swift`** (`Account/`): hoja con contraseña actual (solo si
    `hasPassword`), nueva y confirmar. Mismo patrón de validación en cliente que
    `RegisterView` (8-128 caracteres, coinciden). El botón que la abre dice "Cambiar
    contraseña" o "Agregar contraseña" según `has_password`, y el título de la hoja
    hace lo mismo.
  - **`PasswordChangeError`**: enum propio (no reutiliza `ProfileError`) porque el
    `401` de `POST /auth/me/password` significa siempre "contraseña actual
    incorrecta" (lo garantiza el propio contrato de la API, no hay otra causa posible
    de 401 en ese endpoint una vez pasa el Bearer) — mapearlo a "sesión caducada"
    habría sido un mensaje engañoso. El `401` de `DELETE /auth/me/password` sí es
    sesión caducada de verdad (ese endpoint no lleva contraseña que verificar), así
    que usa un caso distinto (`sessionExpired`) dentro del mismo enum.
  - **Refrescar el perfil tras `204 No Content`**: ni `POST` ni `DELETE
    /auth/me/password` devuelven el usuario actualizado. Sin volver a pedir `GET /me`
    tras un cambio con éxito, la app se quedaba creyendo que `has_password` seguía
    como antes (p. ej. mostrando otra vez el formulario de "poner contraseña por
    primera vez" después de ponerla). `AuthSession.changePassword`/`removePassword`
    llaman a `fetchProfile()` y actualizan `state` al terminar.
- **Verificación de correo por código** (5.5, 6 ago 2026): "soft" — no bloquea nada de
  la app, es solo un aviso en el perfil hasta que se verifica. Código de **6 dígitos**
  (no enlace: así la API no tiene que servir ninguna página web, todo queda en JSON),
  caduca en 2h, máximo **5 intentos fallidos en una ventana móvil de 24h** compartida
  entre códigos (pedir uno nuevo no resetea el contador).
  - **`email_verified`** en `User`: `true` desde el alta para cuentas de Google (ya
    viene verificado en el ID token), `false` por defecto para las de contraseña.
    Expuesto en `UserRead`.
  - **`POST /auth/verify-email/request`** (autenticado): genera el código, invalida
    cualquiera pendiente, lo manda por email. **`POST /auth/verify-email/confirm`**
    (autenticado, body `{code}`): lo valida; `429` + `detail: "too_many_attempts"` si
    se superan los 5 intentos en 24h (sin llegar a comprobar el código), `401` +
    `detail: "invalid_code"` si no coincide o caducó.
  - **`EmailVerificationError`**: mismo patrón que `PasswordChangeError` — el `401`
    significa cosas distintas según el endpoint (al pedir código, sesión caducada; al
    confirmarlo, código incorrecto), así que son dos casos separados
    (`sessionExpired` / `invalidCode`) en vez de uno compartido.
  - **`VerifyEmailView.swift`** (`Account/`): no manda el primer código
    automáticamente al abrir la hoja — solo hay un botón "Enviar código". Como cada
    envío invalida el anterior, auto-enviar al abrir haría que reabrir la hoja por
    accidente (o solo para consultarla) inutilizara un código que la persona ya
    tuviera sin leer en el correo. Tras pedirlo aparece el campo de 6 dígitos +
    "Verificar" + "Reenviar código".
  - **Aviso en el perfil**: pastilla "Sin verificar" + botón "Verificar" bajo el
    email en `AccountProfileView`, solo si `!user.email_verified` (nunca para cuentas
    de Google).
  - **Backend de email en desarrollo**: `ConsoleEmailBackend` (en `ommadawn-api`)
    escribe el email en el log en vez de enviarlo de verdad — no hay proveedor real
    (SMTP/SendGrid) todavía. **Ojo**: el logger `app.email` no tenía ningún
    `logging.basicConfig` que le diera un *handler*, así que sus líneas `INFO` se
    generaban pero no llegaban a la consola (a diferencia de los logs de acceso, que
    son de uvicorn y se configuran aparte) — hubo que arreglarlo en la API para poder
    ver el código al probar en local.
- **Recuperar contraseña** (5.6, 6 ago 2026): mismo patrón que la verificación de
  email (código de 6 dígitos, 2h de caducidad, 5 intentos fallidos en ventana móvil
  de 24h), pero **sin sesión** — es justo el caso que resuelve esto — y con dos
  cuidados de seguridad propios de este flujo.
  - **No revela qué cuentas existen**: `POST /auth/password-reset/request` responde
    `204` exista o no la cuenta con ese `username_or_email` — solo envía el email si
    existe, pero la respuesta es idéntica en ambos casos. `POST
    /auth/password-reset/confirm` da el mismo `401` (`detail: "invalid_code"`) tanto
    si el código es incorrecto/caducado como si la cuenta directamente no existe — un
    único caso para los tres motivos, para que este endpoint sin autenticar no sirva
    para averiguar qué emails/usernames están registrados. Los textos de
    `ForgotPasswordView` mantienen el mismo cuidado ("si existe una cuenta...", nunca
    "hemos enviado" a secas).
  - **Login automático al confirmar**: `confirm` devuelve el mismo `TokenPair` que
    `POST /auth/login` — `AuthSession.confirmPasswordReset` guarda los tokens y deja
    la sesión `signedIn` directamente, sin volver a la pantalla de login a mano
    (mismo patrón que `register`, que encadena un `logIn`).
  - **`PasswordResetError`**: sin caso "cuenta no encontrada" — el único caso de
    "código no válido" (`invalidCode`) cubre también ese motivo, reflejando la misma
    ambigüedad deliberada de la API.
  - **Middleware de auth**: los dos endpoints van sin `Bearer` — añadidos a la lista
    de exclusión de `AuthMiddleware.swift` **antes** de compilar esta vez (la lección
    de `/auth/google` en 5.1 no se repitió).
  - **`ForgotPasswordView.swift`** (`Auth/`): mismo patrón de dos pasos que
    `VerifyEmailView` (botón "Enviar código" primero, campo + "Verificar"/"Reenviar
    código" después). Se abre desde un enlace "¿Olvidaste tu contraseña?" en
    `LoginView`, agrupado en un `VStack` compacto junto a "Crear cuenta" (los dos
    centrados, pegados, separados del resto de la pantalla).

## Colecciones de ediciones (Fase 6, 7 ago 2026)

Agrupar ediciones que pertenecen a **discos distintos** bajo un nombre común — ej.
"Remasterizaciones HDCD" junta la edición HDCD de *Tubular Bells*, la de *Hergest
Ridge*, etc., cada una en su propio `Release`. **No confundir** con una caja física de
varios discos de un mismo álbum: eso ya es un `Release` normal de tipo compilación, no
necesitaba nada nuevo — la idea original del backlog ("agrupar ediciones para cajas
multi-disco") se descartó a favor de este planteamiento, más útil de verdad.

- **Navegación — opción elegida tras comparar tres**: un segmented control "Discos |
  Colecciones" **dentro** de la pestaña Discografía (`ReleaseListView`), no una pestaña
  aparte ni un añadido secundario. Se valoraron tres opciones (mockups en la
  conversación): segmented control (elegida — mismo peso que "Discos", con sus propios
  controles), fila destacada encima de la rejilla (descartada — relega las colecciones
  a contenido secundario), y solo enlace inverso sin listado propio (insuficiente para
  explorar). El enlace inverso desde una edición se hizo **además**, no en lugar de.
- **Modelo**: `Collection` (id, name único, description opcional) + tabla puente con
  `Edition`, **sin campo de orden propio** — el orden dentro de una colección es
  siempre por `release_date` de la edición (las sin fecha, al final), nunca manual.
  Una edición puede estar en 0, 1 o varias colecciones a la vez.
- **`DiscographyStore`**: `fetchCollections`, `fetchCollection(id:)`, `createCollection`,
  `updateCollection`, `deleteCollection` (solo si `edition_count == 0`, mismo criterio
  que sellos), `addEdition(_:toCollection:)` / `removeEdition(_:fromCollection:)`.
- **`Models.swift`**: `CollectionSummary` (listado, con `sample_cover_urls` — portadas
  de las 2-3 primeras ediciones por fecha), `CollectionDetail` (detalle, con
  `editions: [CollectionEdition]`), `CollectionEdition` (una edición dentro de una
  colección, con `release_id`/`release_title`/`release_type` porque aquí — a diferencia
  de `Edition` anidada bajo su `Release` — el disco de origen no es implícito),
  `CollectionTag` (vista mínima `id`+`name`, colgada de `Edition.collections`).
- **`ReleaseListView`**: el "+" de admin crea un disco o una colección según el scope
  activo; en modo colecciones no hay filtro de tipo ni grid/lista todavía (una sola
  lista alfabética basta con el catálogo actual). El array `collections` vive en
  `ReleaseListView` (no en `CollectionListView`), pasado por `@Binding` — mismo patrón
  que ya usa `releases` con `ReleaseEditView`, para que crear una colección la añada al
  listado al momento sin depender de un pull-to-refresh.
- **`CollectionListView.ChainedCovers`**: hasta 3 portadas encadenadas en diagonal
  (menos si la colección tiene menos ediciones), reutilizable.
- **`CollectionDetailView`**: tocar una fila pide el `Release` completo (esta vista
  solo tiene los datos resumidos de `CollectionEditionRead`) y navega — mismo patrón de
  "cargar antes de navegar" que ya usa la app. Para admins, menú ⋯ con "Editar colección"
  (nombre/descripción) y "Eliminar colección" (deshabilitado si tiene ediciones).
  Borrar/editar aquí, igual que borrar un disco, no refresca `CollectionListView`
  automáticamente (mismo comportamiento ya aceptado en el resto de la app).
- **`CollectionFormView`** (antes `CollectionCreateView`, renombrada): un único
  formulario nombre+descripción sirve para crear *y* editar (`existing:` los
  distingue), en vez de duplicar la hoja.
- **Tags en `EditionEditView`** (solo en modo edición, llamadas inmediatas — igual que
  imágenes): sección "Colecciones" con `CollectionTagPickerView`, mismo patrón que
  `LabelPickerView` (buscar o crear) pero **multi-selección**, porque una edición no
  está limitada a una sola colección como sí lo está a un sello.
- **Enlace inverso "Parte de: X"**: en `ReleaseDetailView`, si la edición mostrada
  pertenece a alguna colección. Usa su **propio** `.navigationDestination(item:)`
  (`selectedCollectionTag`) en vez de depender del `.navigationDestination(for:
  CollectionSummary.self)` de `CollectionListView` — esa vista no siempre está montada
  (solo cuando el scope activo es "Colecciones"), así que ese destino no estaría
  registrado si el disco se abrió desde el scope "Discos".
- **`EditionRead.collections` tuvo que añadirse aparte**: hacía falta tanto para
  precargar los tags al editar como para el enlace inverso, y no se pidió en la
  primera ronda del contrato — se detectó al implementar 6.4/6.5, no antes.

### Backlog — Fase 4 (completa)

Leyenda: 🟢 solo app · 🔴 requiere cambio en la API primero

| # | Mejora | Requiere API |
|---|---|---|
| ~~4.1~~ | ~~**Rediseño de vista de discografía**~~: portada grande, galería, secciones desplegables, banderas de país. ✅ hecho (ago 2026). | ✅ |
| ~~4.2~~ | ~~**Nombre de edición en el detalle**~~: `edition_name` se muestra junto al título — "Tubular Bells – Deluxe Edition". ✅ hecho. | ✅ |
| ~~4.3~~ | ~~**Créditos por pista**~~: créditos editables en `EditionEditView` (via linked recordings) y mostrados en `ReleaseDetailView` bajo cada track. ✅ hecho. | ✅ |
| ~~4.4~~ | ~~**Sello seleccionable**~~: `LabelPickerView` con buscador en tiempo real, contador de ediciones por sello, crear nuevo (POST /labels), eliminar si 0 ediciones. `Edition.label` es ahora `LabelRead` anidado (no texto libre). ✅ hecho (6 ago 2026). | ✅ |

### Backlog — Fase 5: Mejoras de autenticación

**Login con Google** (decisiones tomadas, ago 2026): SDK oficial `GoogleSignIn-iOS`
(no `ASWebAuthenticationSession` a mano — menos código propio, mejor soporte de casos
límite). La app solo obtiene el **ID token de Google** y se lo pasa a la API; la API
verifica el token con Google y emite el par access/refresh propio de siempre —
`AuthSession` no distingue después si la sesión vino de contraseña o de Google. Conflicto
de email (alguien intenta entrar con Google usando un email que ya existe con
contraseña): **error con sugerencia**, no auto-vinculación ni prompt de vinculación en el
propio login — es la opción más segura y sin fricción en el flujo feliz; la vinculación
vive aparte, en el perfil, bajo control explícito del usuario ya autenticado.

| # | Mejora | Estado | Requiere API |
|---|---|---|---|
| 5.1 | **Google Sign-In — login/registro básico**: botón "Continuar con Google" funcional en `LoginView`. Ver desglose abajo. | ✅ hecho (6 ago 2026) | ✅ |
| 5.2 | **Conflicto de email**: email de Google ya existente con contraseña → `409 email_conflict`, mensaje con sugerencia, sin auto-vincular ni duplicar. | ✅ hecho (6 ago 2026) | ✅ |
| 5.3 | **Vincular/desvincular Google desde el perfil**: botón "Conectar con Google" (mismo flujo SDK, llama a un endpoint de vinculación) y "Desconectar Google". Ver desglose abajo. | ✅ hecho (6 ago 2026) | ✅ |
| 5.4 | **Cambiar/agregar/quitar contraseña**: hoja en `AccountProfileView` con contraseña actual (si aplica) + nueva + confirmación. Ver desglose abajo. | ✅ hecho (6 ago 2026) | ✅ |
| 5.5 | **Verificación de correo**: código de 6 dígitos por email, "soft" (no bloquea nada). Ver desglose abajo. | ✅ hecho (6 ago 2026) | ✅ |
| 5.6 | **Recuperar contraseña** ("¿Olvidaste tu contraseña?"): código de 6 dígitos, no revela qué cuentas existen, login automático al confirmar. Ver desglose abajo. | ✅ hecho (6 ago 2026) | ✅ |

**Desglose de 5.1** (todo hecho el 6 ago 2026, ver también la sección "Login con Google" más arriba):

| # | Subtarea | Dónde |
|---|---|---|
| 5.1.0 | Client ID OAuth en Google Cloud Console (iOS + Web/servidor) | Google Cloud Console |
| 5.1.1 | `POST /auth/google`: verifica el ID token, crea/loguea, `409 email_conflict` | `ommadawn-api` |
| 5.1.2 | SDK `GoogleSignIn-iOS` + `Info.plist` + configuración del SDK | app |
| 5.1.3 | `AuthSession.signInWithGoogle(idToken:)` | app |
| 5.1.4 | Botón "Continuar con Google" funcional en `LoginView` | app |
| 5.1.5 | Manejo de errores (cancelado, sin red, conflicto, servidor) | app |
| 5.1.6 | Probado en simulador y en dispositivo físico contra pre | app |
| 5.1.7 | *(bonus, no estaba en el plan original)* `has_google` en el perfil + username editable una sola vez cuando lo asignó Google | app + API |

**Desglose de 5.3** (todo hecho el 6 ago 2026):

| # | Subtarea | Dónde |
|---|---|---|
| 5.3.1 | `POST`/`DELETE /auth/me/google`: vincula (rechaza si el `google_id` ya es de otro usuario) / desvincula (rechaza si no hay contraseña propia) | `ommadawn-api` |
| 5.3.2 | `AuthSession.linkGoogleAccount(idToken:)` + botón "Conectar con Google" | app |
| 5.3.3 | `AuthSession.unlinkGoogleAccount()` + botón "Desconectar Google" con `confirmationDialog` | app |
| 5.3.4 | Manejo de errores (`google_already_linked`, `google_only_access`, cancelado, servidor) como `.alert` en vez de texto en la sección | app |
| 5.3.5 | Probado en simulador | app |

**Desglose de 5.4** (todo hecho el 6 ago 2026):

| # | Subtarea | Dónde |
|---|---|---|
| 5.4.1 | `POST /auth/me/password`: cambia o pone la contraseña por primera vez (`current_password` opcional a nivel de schema, obligatoria solo si la cuenta ya tenía una) | `ommadawn-api` |
| 5.4.2 | `AuthSession.changePassword(currentPassword:newPassword:)` | app |
| 5.4.3 | `ChangePasswordView.swift`: hoja con validación local (8-128 caracteres, coinciden) | app |
| 5.4.4 | Manejo de errores (`wrongCurrentPassword`, `invalidData`, servidor) | app |
| 5.4.5 | Probado en simulador | app |
| 5.4.6 | *(bonus, no estaba en el plan original)* `DELETE /auth/me/password` (quitarla, rechaza si no hay Google vinculado) + `has_password` en el perfil + botón "Quitar contraseña" | app + API |

**Desglose de 5.5** (todo hecho el 6 ago 2026):

| # | Subtarea | Dónde |
|---|---|---|
| 5.5.1 | `POST /auth/verify-email/request` + `/confirm`: código de 6 dígitos, caduca en 2h, máximo 5 intentos fallidos en ventana móvil de 24h | `ommadawn-api` |
| 5.5.2 | `AuthSession.requestEmailVerification()` + `confirmEmailVerification(code:)` | app |
| 5.5.3 | `VerifyEmailView.swift` + pastilla "Sin verificar" en `AccountProfileView` | app |
| 5.5.4 | Manejo de errores (`invalidCode`, `tooManyAttempts`, sesión caducada, servidor) | app |
| 5.5.5 | Probado en simulador (incluye arreglar el logger `app.email`, que no llegaba a la consola en dev) | app + API |

**Desglose de 5.6** (todo hecho el 6 ago 2026):

| # | Subtarea | Dónde |
|---|---|---|
| 5.6.1 | `POST /auth/password-reset/request` + `/confirm`: código de 6 dígitos, sin revelar si la cuenta existe, login automático (`TokenPair`) al confirmar | `ommadawn-api` |
| 5.6.2 | `AuthSession.requestPasswordReset(usernameOrEmail:)` + `confirmPasswordReset(usernameOrEmail:code:newPassword:)` | app |
| 5.6.3 | `ForgotPasswordView.swift` + enlace "¿Olvidaste tu contraseña?" en `LoginView` | app |
| 5.6.4 | Manejo de errores (`invalidCode` cubre también "cuenta no existe", `tooManyAttempts`, servidor) | app |
| 5.6.5 | Probado en simulador, incluida una cuenta inexistente para confirmar que la respuesta no la delata | app |

Con esto, la **Fase 5 queda completa**: login con Google, conflicto de email, vincular/
desvincular, cambiar/agregar/quitar contraseña, verificar correo y recuperar contraseña.

### Backlog — Fase 6 (completa)

Ver también la sección "Colecciones de ediciones" más arriba.

| # | Subtarea | Dónde |
|---|---|---|
| 6.1 | Modelo `Collection` + tabla puente con `Edition` (sin orden propio, siempre por `release_date`) + endpoints CRUD | `ommadawn-api` |
| 6.2 | Segmented "Discos \| Colecciones" en `ReleaseListView` + `CollectionListView` | app |
| 6.3 | `CollectionDetailView` (ediciones ordenadas, cargar disco al tocar una fila) | app |
| 6.4 | Tags de colección en `EditionEditView` (`CollectionTagPickerView`, buscar o crear, multi-selección) | app |
| 6.5 | Enlace inverso "Parte de: X" en `ReleaseDetailView` | app |
| 6.6 | Probado en simulador | app |
| 6.7 | *(bonus, no estaba en el plan original)* `PATCH /discography/collections/{id}` (editar nombre/descripción) | `ommadawn-api` |
| 6.8 | *(bonus)* Botón "Eliminar colección" en `CollectionDetailView` (solo si 0 ediciones) | app |
| 6.9 | *(bonus)* Botón "Editar colección" — `CollectionFormView` unifica crear y editar | app |
| 6.10 | Probado borrar/editar en simulador | app |

> `EditionRead.collections` (6.4/6.5) también fue un campo pedido sobre la marcha, no
> en la ronda inicial de 6.1 — mismo patrón que `has_google`/`has_password` en la Fase 5:
> se detecta el hueco al implementar la UI que lo necesita, no antes.

### Backlog — Fase 7: Foro / contribuciones (en marcha, 8 ago 2026)

Replanteada respecto a la idea original ("sistema estructurado de propuestas con
diffs y aprobación automática"): en vez de eso, un **foro de discusión** atado al
catálogo — la gente propone y discute, un admin decide qué aplicar **a mano**, con
las pantallas de edición que ya existen. Mucho menos que construir, y de propina da
discusión real entre varias personas antes de que el admin actúe.

- **`Subforum`**: secciones del foro — `id`, `name` (único), `description`
  opcional, `icon` (SF Symbol, opcional), `position` (orden manual). Hoy solo
  existe uno, sembrado por migración: **"Discusiones"**. Pensado para poder añadir
  más subforos en el futuro (ej. "Anuncios", "Ayuda") sin cambiar el modelo otra
  vez. Sin CRUD de subforos desde la API todavía (con uno solo no hace falta).
- **`ForumThread`**: título, cuerpo, autor, `subforum_id` (**obligatorio**: todo
  hilo vive en un subforo) + `entity_type` (nullable: `"release"` / `"edition"` /
  `"discography"` general / futuros dominios como conciertos — y también
  preparado para posts **sin tema**, aunque la app no lo exponga todavía) +
  `entity_id`, estado (`open` / `resolved` / `closed`), `resolution_note`
  opcional. `subforum_id` y `entity_type`/`entity_id` son independientes entre sí:
  el primero dice **dónde** vive el hilo, el segundo **a qué** se refiere dentro
  de ese subforo (un futuro subforo "Anuncios" tendría hilos sin `entity_type`).
- **`ForumComment`**: hilo, autor, cuerpo.
- **Crear hilo o comentar exige `email_verified = true`** — mismo criterio de
  "soft" que el resto de la app (no bloquea nada más), pero participar en el foro sí
  requiere haber confirmado el email.
- **Textos en Markdown**: el cuerpo de un hilo y de un comentario se escriben con
  el mismo editor de la Fase 4 (`MarkdownEditorSection` + toolbar de negrita/
  cursiva/enlace/lista/cita + cheatsheet + preview) y se muestran ya renderizados
  con el nuevo `MarkdownBlock` (`Shared/MarkdownTextEditor.swift`) — una variante
  siempre expandida de `DynamicMarkdownWebView`, a diferencia de
  `CollapsibleMarkdownSection` (que se pliega tras un chevron): aquí el texto ES
  el contenido principal, no un extra opcional.
- **`ForumStore`** (`Forum/ForumStore.swift`): mismo patrón que `DiscographyStore`.
  `fetchSubforums`, `fetchThreads(subforumId:entityType:entityId:status:)`,
  `fetchThread(id:)`, `createThread(subforumId:title:body:entityType:entityId:)`,
  `addComment(threadID:body:)`, `updateThreadStatus(id:status:resolutionNote:)`.
  `ForumError` distingue `.sessionExpired` (401) de `.emailNotVerified` (403 al
  crear/comentar) y `.forbidden` (403 al cambiar estado, no admin) — mismo criterio
  que `PasswordChangeError`/`EmailVerificationError`: un mismo código HTTP significa
  cosas distintas según el endpoint, así que son casos separados.
- **Hilos en el detalle de disco/edición** (7.2, en marcha): sección "Discusión" en
  `ReleaseDetailView`, con dos entradas — "Discusiones del disco (N)" y
  "Discusiones de esta edición (N)" — donde N es el número de hilos **abiertos**
  en ese momento (cargado con `fetchThreads(status: .open)` al aparecer la vista y
  al cambiar de edición). Cada una abre `ForumThreadListView` como hoja (necesita
  su propio `NavigationStack`, ya que una `.sheet` no hereda el de la vista que la
  abre) filtrada por `entityType`/`entityId`. El subforo "Discusiones" se resuelve
  una vez (`fetchSubforums().first`, hoy es el único) y se reutiliza tanto para
  filtrar como para crear hilos nuevos (`subforum_id` es obligatorio al crear). El
  botón de "+" para crear un hilo se deshabilita mientras el subforo no ha
  cargado. `ForumThreadDetailView` muestra cabecera + cuerpo + comentarios, y un
  compositor de comentario al final (oculto si el hilo no está `.open`).
  `ForumThreadComposeView` es la hoja de crear hilo (título + `MarkdownEditorSection`).
- **Admin: resolver/cerrar/reabrir un hilo** (7.4, 9 ago 2026): menú `⋯` en la
  toolbar de `ForumThreadDetailView`, solo visible a admins. En un hilo `.open`:
  "Marcar como resuelto" (abre `ForumResolveSheet`, nota de resolución opcional,
  ej. "Aplicado en la edición X") o "Cerrar hilo" (`confirmationDialog`, sin nota).
  En un hilo `.resolved`/`.closed`: "Reabrir hilo". Hoy ambos estados bloquean
  comentarios nuevos por igual (`if thread.status == .open` gatea el compositor);
  la diferencia entre "resuelto" y "cerrado" es solo semántica (hubo una acción
  concreta derivada del hilo vs. se corta sin resultado) más la nota opcional,
  sin distinto comportamiento todavía.
  **Contador "Abiertas/Totales"**: `forumLinks` en `ReleaseDetailView` cambió de
  mostrar solo el número de abiertas a mostrar `(abiertas/totales)`, ej.
  "Discusiones del disco (0/2)", con la cabecera de la sección explicando el
  formato ("Discusiones (Abiertas/Totales)"). `loadCounts(entityType:entityId:)`
  pide ambos números en paralelo (`async let`). Los `.sheet` de
  `showingReleaseForum`/`showingEditionForum` ganan `onDismiss` para recalcular
  el contador al volver — si no, al resolver/cerrar un hilo y salir de la hoja,
  el número se quedaba con el valor cargado al entrar (no había nada que lo
  refrescara).
- **Pestaña Inicio** (7.5, 9 ago 2026, ampliada el mismo día): `Home/HomeView.swift`,
  primera pestaña de `RootTabView` (Inicio → Discografía → Tours). Tres bloques,
  cada uno con su propia pantalla "ver todo":
  1. **Novedades**: últimos 2 hilos del subforo **"Novedades"** (nuevo,
     `admin_only = true` — solo un admin puede abrir hilos ahí; leer y comentar
     sigue siendo de cualquiera con email verificado). "Ver todas las novedades"
     abre `ForumThreadListView(subforumId:)` filtrado a ese subforo. Reemplaza
     la versión inicial con noticias `DummyNews` hardcodeadas (7.5 original).
  2. **Actividad reciente del foro**: últimos 5 hilos de cualquier subforo/
     entidad (`ForumStore.fetchThreads(limit: 100)`, ordenados por `updated_at`
     descendente en el cliente — la API ya devuelve "más recientes primero",
     pero por creación, no por última actividad; si el foro crece mucho, esto
     necesitará un parámetro de orden en la API en vez de sobre-pedir).
     Reutiliza `ForumThreadRow(showsContext: true)` (mismo componente que
     `ForumThreadListView`, con una línea extra de subforo + tipo de entidad).
     "Ver todos los subforos" abre `SubforumListView` (lista los subforos,
     entrar en uno lleva a todos sus hilos paginados).
  3. **Changelog del catálogo**: contenido de ejemplo (`Home/ChangelogEntry.swift`,
     `sampleChangelog`) — sin backend todavía, pendiente de un campo `updated_at`
     nuevo en `Release`/`Edition` que la API no tiene. "Ver todo el changelog"
     abre `ChangelogListView`, paginada **localmente** sobre el array de ejemplo
     (botón "Cargar más" que revela más elementos del mismo array, sin llamada
     a red — es solo para probar la interacción, no hay datos reales que traer).
  `ForumThreadRow` se expuso (dejó de ser `private`) en `ForumThreadListView.swift`
  para poder reutilizarlo en el bloque de actividad.
- **Subforo "Novedades" + paginación del foro** (9 ago 2026, cambio de contrato):
  - **`Subforum` gana `admin_only: Bool`**, expuesto en `SubforumRead` — permite
    a la app ocultar/deshabilitar el botón de crear hilo sin esperar a que el
    servidor lo rechace. Seed: `Subforum(name="Novedades", icon="megaphone",
    position=1, admin_only=true)`, junto al ya existente `Subforum(name=
    "Discusiones", position=0, admin_only=false)`.
  - **`POST /forum/threads` gana un segundo motivo de `403`**: además de
    `email_not_verified` (código corto), un subforo `admin_only` rechaza a
    quien no es admin con un `detail` en prosa ("Se requieren permisos de
    administrador") — distinguibles por el propio `detail`, mismo criterio que
    el resto de la app. `ForumError` gana `.subforumRestricted` junto a
    `.emailNotVerified`, ambos mapeados desde el mismo case `.forbidden` del
    Output generado inspeccionando `detail`.
  - **`GET /forum/threads` pasa a paginar**: `limit` (por defecto 20, máximo
    100) y `offset`, combinados con los filtros ya existentes. **Cambio de
    forma de la respuesta** (de array plano a objeto) — decisión deliberada
    dentro de `/v1` sin versionar, porque el foro no tiene más clientes
    todavía: `ThreadListPage { items: [ThreadListRead], total: int }`, alias
    `ForumThreadPage` en `Models.swift`. `total` es el número de hilos que
    cumplen el filtro sin paginar (no el tamaño de `items`), útil tanto para
    "Cargar más" como para contar sin traer los hilos (`loadCounts` en
    `ReleaseDetailView` ahora pide `limit: 1` y lee solo `.total`, más barato
    que traer todo y contar `.count` en el cliente).
  - **`ForumThreadListView` gana paginación real**: `pageSize = 20`, botón
    "Cargar más" al final de la lista mientras `threads.count < total`. También
    gana un `subforumId: Int?` explícito (usado por `SubforumListView` al
    entrar en un subforo concreto) y `showsCloseButton: Bool` (`false` cuando
    se empuja dentro de un `NavigationStack` ya existente en vez de presentarse
    como hoja propia) — dejó de envolverse en su propio `NavigationStack`
    internamente; cada llamador que la presenta como `.sheet` la envuelve él
    mismo (`ReleaseDetailView`, `ReleaseListView`, `HomeView`).
  - **`SubforumListView.swift`** (nuevo, `Forum/`): lista los subforos
    (`fetchSubforums`), cada fila con icono/nombre/descripción; entrar en uno
    empuja `ForumThreadListView(subforumId:showsCloseButton: false)` dentro del
    mismo `NavigationStack` (no como hoja aparte).
- **Discusión general de discografía** (7.3): en `ReleaseListView`, cápsula flotante
  independiente en la esquina inferior **izquierda** (separada de la de buscar/
  filtrar/vista, que sigue a la derecha — no son la misma familia de controles) con
  el botón "+" de admin (crear disco/colección) y un icono de discusión que abre
  `ForumThreadListView` con `entityType: .discography`, `entityId: nil` — hilos que
  no cuelgan de ningún disco concreto.

| # | Subtarea | Dónde | Estado |
|---|---|---|---|
| 7.1 | Modelo `Subforum`/`ForumThread`/`ForumComment` + endpoints (subforos, crear, listar/filtrar, comentar, cambiar estado) | `ommadawn-api` | ✅ hecho (8 ago 2026) |
| 7.2 | Hilos del foro en el detalle de disco/edición (listar, crear, comentar) | app | ✅ hecho (9 ago 2026) |
| 7.3 | Hilos generales de Discografía (sin disco concreto) | app | ✅ hecho (9 ago 2026) |
| 7.4 | Admin: resolver/cerrar un hilo | app | ✅ hecho (9 ago 2026) |
| 7.5 | Pestaña Inicio con casos abiertos del foro | app | ✅ hecho (9 ago 2026) |
| 7.6 | Admin: gestión de subforos (orden, icono, nombre, crear, borrar) | app + API | En marcha |
| 7.7 | Poder agregar imágenes en el foro (hilos y comentarios) | app + API | Pendiente |
| 7.8 | Probado en simulador | app | Pendiente |

### Backlog — Fases futuras

| Fase | Contenido | Requiere API |
|---|---|---|
| **8** | **Valoración de discos**: puntuar discos/ediciones. Sin definir todavía — primera vez que se aborda. | 🔴 Sin definir |
| **9** | **Colección personal**: cada usuario marca qué ediciones tiene, con estado del disco y la funda (escala Discogs: Mint / NM / VG+ / VG / G / F / P). Vista de colección propia + botón en detalle de edición. | 🔴 API: modelo `CollectionEntry` (user, edition, disc_condition, sleeve_condition, notas), endpoints `GET/POST /collection`, `PATCH/DELETE /collection/{id}` |
| **10** | **Conciertos**: giras, fechas, setlists. | 🔴 Sin definir todavía |
| **11** | **Libros**: bibliografía. | 🔴 Sin definir todavía |

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
│   ├── ommadawnApp.swift        # @main · posee la AuthSession, configura GIDSignIn
│   ├── Info.plist               # solo CFBundleURLTypes (login con Google); se fusiona con el auto-generado
│   ├── ContentView.swift        # Vista raíz: enruta según el estado de sesión
│   ├── RootTabView.swift        # Shell tras el login: cabecera común + TabView
│   ├── LoginView.swift
│   ├── Auth/
│   │   ├── AuthSession.swift    # @Observable: sesión + perfil + avatar + logout + Google
│   │   ├── GoogleAuthConfig.swift # Client ID iOS + Web/servidor (login con Google)
│   │   ├── RegisterView.swift
│   │   └── ForgotPasswordView.swift # Recuperar contraseña por código de 6 dígitos
│   ├── Account/
│   │   ├── AccountMenu.swift          # Menú desplegable (nombre, apariencia, admin, logout)
│   │   ├── AccountProfileView.swift   # Hoja de perfil: avatar + datos editables
│   │   ├── ChangePasswordView.swift   # Cambiar/agregar contraseña
│   │   ├── VerifyEmailView.swift      # Verificación de email por código de 6 dígitos
│   │   ├── AccountAvatarView.swift    # Avatar circular reutilizable
│   │   └── User+Presentation.swift    # displayName, avatarURL
│   ├── Admin/                    # Gestión de administradores (solo superadmin)
│   │   ├── AdminStore.swift
│   │   └── AdminUsersView.swift
│   ├── Settings/                 # Ajustes de la app
│   │   └── SettingsView.swift    # apariencia (sincronizada con servidor) + admin
│   ├── Discography/              # Fase 4: catálogo + edición para admins · Fase 6: colecciones
│   │   ├── DiscographyStore.swift
│   │   ├── ReleaseListView.swift
│   │   ├── ReleaseDetailView.swift
│   │   ├── ReleaseEditView.swift        # crear/editar/eliminar disco (solo admins)
│   │   ├── EditionEditView.swift        # crear/editar/eliminar edición + tracklist + imágenes
│   │   ├── Release+Presentation.swift
│   │   ├── CollectionListView.swift     # listado de colecciones + CollectionFormView (crear/editar)
│   │   ├── CollectionDetailView.swift
│   │   └── CollectionTagPickerView.swift # multi-selección de colecciones para una edición
│   ├── Home/                       # Fase 7: pestaña Inicio (novedades + actividad + changelog)
│   │   ├── HomeView.swift
│   │   ├── ChangelogEntry.swift          # modelo + sampleChangelog (contenido de ejemplo)
│   │   └── ChangelogListView.swift       # "ver todo" del changelog, paginado localmente
│   ├── Forum/                     # Fase 7: foro de discusión (subforos + hilos + comentarios)
│   │   ├── ForumStore.swift
│   │   ├── Forum+Presentation.swift      # displayName/tintColor de estado y tipo de entidad
│   │   ├── ForumThreadListView.swift     # lista paginada de hilos de un subforo/entidad + crear
│   │   ├── ForumThreadDetailView.swift   # hilo + comentarios + compositor de comentario
│   │   ├── ForumThreadComposeView.swift  # hoja de crear hilo
│   │   └── SubforumListView.swift        # explorar subforos → hilos paginados de cada uno
│   ├── Shared/                   # Componentes reutilizables entre dominios
│   │   ├── Country.swift              # modelo Country + NSLocale.isoCountryCodes + extraCodes
│   │   ├── CountryPickerView.swift    # hoja de selección de país con frecuentes + buscador
│   │   ├── LabelPickerView.swift      # hoja de selección de sello discográfico
│   │   ├── GoogleMark.swift           # la "G" en degradado (botón de login + icono en perfil)
│   │   ├── UIApplication+TopViewController.swift # presentar el navegador embebido del SDK de Google
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
| **4 — Discografía** | Listado y detalle de discos, edición completa para admins. | ✅ Hecha |
| **5 — Mejoras de autenticación** | Login con Google (SDK oficial + vinculación de cuenta), cambio de contraseña, verificación de correo y recuperación por email. | ✅ Hecha |
| **6 — Colecciones de ediciones** | Agrupar ediciones de discos distintos bajo un nombre común (ej. "Remasterizaciones HDCD"). | ✅ Hecha |
| **7 — Foro / contribuciones** | Foro de discusión atado al catálogo (discos, ediciones, discografía en general, y futuros dominios); solo un admin aplica los cambios. Pestaña Inicio con casos abiertos. | 🚧 En marcha |
| **8 — Valoración de discos** | Puntuar discos/ediciones. | Pendiente |
| **9 — Colección personal** | Cada usuario registra las ediciones que tiene, con estado de disco y funda (escala Discogs). | Pendiente |
| **10 — Conciertos** | Giras, fechas, setlists. | Pendiente |
| **11 — Libros** | Bibliografía. | Pendiente |
| **Siguientes** | Otras secciones a acordar con el usuario. | Pendiente |
