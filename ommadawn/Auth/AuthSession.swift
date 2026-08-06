//
//  AuthSession.swift
//  ommadawn
//
//  Estado de sesión de la app. Es el "modelo" que observa la UI: sabe si hay
//  usuario autenticado y expone iniciar/cerrar sesión.
//
//  Posee el cliente autenticado y el renovador — recuerda que ambos deben
//  crearse UNA vez y compartirse (cada renovador coordina sus propias
//  renovaciones). AuthSession es ese dueño único.
//

import Foundation
import Observation
import OmmadawnAPI

/// Motivos por los que un login puede fallar, en términos de la app.
///
/// Mapea los códigos del contrato a algo que la pantalla pueda mostrar. La UI
/// traduce cada caso a un texto; el modelo no guarda cadenas de interfaz.
enum LoginError: Error {
    case invalidCredentials   // 401 — usuario o contraseña incorrectos
    case accountDisabled      // 403 — cuenta desactivada
    case invalidData          // 422 — no debería pasar si validamos en cliente
    case unexpected(Int)      // cualquier otro estado no contemplado
    case network(Error)       // sin conexión / fallo de transporte
}

/// Motivos por los que un login con Google puede fallar.
///
/// No incluye "cancelado por el usuario": eso ocurre en el SDK de Google antes
/// de llegar a llamar a este método, no es un error de la API.
enum GoogleSignInError: Error {
    case invalidToken     // 401 — el ID token de Google no es válido (firma, caducidad, audiencia)
    case accountDisabled  // 403 — cuenta desactivada
    case emailConflict    // 409 — el email ya existe con contraseña, sin Google vinculado
    case invalidData      // 422 — no debería pasar si el SDK nos da un id_token bien formado
    case unexpected(Int)
    case network(Error)
}

/// Motivos por los que cambiar (o poner por primera vez) la contraseña
/// puede fallar.
///
/// El servidor documenta que, en este endpoint, un `401` una vez pasado el
/// `Bearer` solo puede significar una cosa: la `current_password` enviada
/// no coincide con la actual — por eso NO se mapea a `sessionExpired` como
/// en el resto de operaciones (sería un mensaje engañoso aquí).
enum PasswordChangeError: Error {
    case wrongCurrentPassword // 401 al cambiarla — la current_password no coincide
    case sessionExpired       // 401 al quitarla — aquí no hay contraseña que verificar, es sesión
    case invalidData          // 422 — nueva contraseña fuera de longitud, etc.
    case passwordOnlyAccess   // 409 — al quitarla: no hay Google vinculado, se quedaría sin acceso
    case unexpected(Int)
    case network(Error)
}

/// Motivos por los que un registro puede fallar.
enum RegisterError: Error {
    case alreadyTaken             // 409 — usuario o email ya en uso
    case invalidData              // 422 — datos rechazados por el servidor
    case registeredButLoginFailed // registró pero el auto-login falló (raro)
    case unexpected(Int)
    case network(Error)
}

/// Motivos por los que editar el perfil o el avatar puede fallar.
enum ProfileError: Error {
    case invalidData        // 422 — datos rechazados o formato de imagen no soportado
    case imageTooLarge      // 413 — avatar por encima de 10 MB
    case usernameTaken      // 409 — al editar username: ya lo tiene otra cuenta
    case usernameLocked     // 409 — al editar username: ya se gastó el único cambio permitido
    case googleAlreadyLinked // 409 — al vincular: ese Google ya pertenece a otra cuenta
    case googleOnlyAccess    // 409 — al desvincular: Google es la única forma de entrar
    case sessionExpired     // 401
    case unexpected(Int)
    case network(Error)
}

@MainActor
@Observable
final class AuthSession {
    /// En qué punto está la sesión. La vista raíz enruta según esto.
    enum State {
        case loading          // arrancando: aún no sabemos si hay sesión
        case signedOut        // sin sesión → pantalla de login
        case signedIn(User)   // con sesión → app
    }

    private(set) var state: State = .loading

    // El entorno puede cambiar en debug (selector en Ajustes).
    // Se persiste en UserDefaults para sobrevivir relanzamientos.
    private(set) var environment: APIEnvironment
    private let tokenStore: TokenStore
    private var refresher: TokenRefresher
    private(set) var client: Client

    static let environmentKey = "api_environment"

    /// - Parameter environment: si se omite, lee el último entorno guardado
    ///   (o `.development` si no hay ninguno). Pásalo explícitamente en tests/
    ///   previews para no depender de `UserDefaults`.
    init(
        environment: APIEnvironment? = nil,
        tokenStore: TokenStore = .shared,
        initialState: State = .loading
    ) {
        let env: APIEnvironment
        if let environment {
            env = environment
        } else {
            let raw = UserDefaults.standard.string(forKey: Self.environmentKey)
            env = raw.flatMap(APIEnvironment.init(rawValue:)) ?? .development
        }
        let refresher = TokenRefresher(tokenStore: tokenStore, environment: env)
        self.environment = env
        self.tokenStore = tokenStore
        self.refresher = refresher
        self.client = Client.authenticated(environment: env, refresher: refresher)
        self.state = initialState
    }

    /// Cambia el entorno de la API, cierra la sesión actual y recrea el cliente.
    /// Solo debe llamarse desde la pantalla de Ajustes (entorno de debug).
    func switchEnvironment(_ newEnvironment: APIEnvironment) async {
        UserDefaults.standard.set(newEnvironment.rawValue, forKey: Self.environmentKey)
        await logOut()
        environment = newEnvironment
        let newRefresher = TokenRefresher(tokenStore: tokenStore, environment: newEnvironment)
        refresher = newRefresher
        client = Client.authenticated(environment: newEnvironment, refresher: newRefresher)
    }

    /// Al arrancar la app: si hay tokens guardados, valida la sesión pidiendo
    /// `/me`. Cualquier fallo (caducada, red) lleva a la pantalla de login.
    func restore() async {
        guard (try? await tokenStore.load()) != nil else {
            state = .signedOut
            return
        }
        do {
            let user = try await fetchProfile()
            applyTheme(from: user)
            state = .signedIn(user)
        } catch {
            state = .signedOut
        }
    }

    /// Inicia sesión con username **o** email + contraseña.
    ///
    /// - Throws: siempre un `LoginError`, listo para que la pantalla lo pinte.
    func logIn(usernameOrEmail: String, password: String) async throws {
        do {
            let output = try await client.login_api_v1_auth_login_post(
                .init(body: .json(.init(
                    username_or_email: usernameOrEmail,
                    password: password
                )))
            )

            switch output {
            case .ok(let ok):
                let pair = try ok.body.json
                // Guarda tokens + caducidad (para el refresco proactivo).
                try await tokenStore.save(AuthTokens(pair: pair))
                // El login solo devuelve tokens; el perfil se pide aparte.
                let user = try await fetchProfile()
                applyTheme(from: user)
                state = .signedIn(user)

            case .unauthorized:
                throw LoginError.invalidCredentials
            case .forbidden:
                throw LoginError.accountDisabled
            case .unprocessableContent:
                throw LoginError.invalidData
            case .undocumented(let statusCode, _):
                throw LoginError.unexpected(statusCode)
            }
        } catch let error as LoginError {
            throw error
        } catch {
            // Transporte, decodificación o /me fallando: todo cae aquí.
            throw LoginError.network(error)
        }
    }

    /// Inicia sesión (o registra, si el email es nuevo) con el ID token que ya
    /// ha obtenido el SDK de Google en el cliente.
    ///
    /// La API verifica el token contra Google y devuelve el mismo par de
    /// tokens que `logIn` — a partir de ahí no hay diferencia entre una
    /// sesión que empezó con contraseña o con Google.
    ///
    /// - Throws: siempre un `GoogleSignInError`, listo para que la pantalla lo pinte.
    func signInWithGoogle(idToken: String) async throws {
        do {
            let output = try await client.google_login_api_v1_auth_google_post(
                .init(body: .json(.init(id_token: idToken)))
            )

            switch output {
            case .ok(let ok):
                let pair = try ok.body.json
                try await tokenStore.save(AuthTokens(pair: pair))
                let user = try await fetchProfile()
                applyTheme(from: user)
                state = .signedIn(user)

            case .unauthorized:
                throw GoogleSignInError.invalidToken
            case .forbidden:
                throw GoogleSignInError.accountDisabled
            case .conflict:
                throw GoogleSignInError.emailConflict
            case .unprocessableContent:
                throw GoogleSignInError.invalidData
            case .undocumented(let statusCode, _):
                throw GoogleSignInError.unexpected(statusCode)
            }
        } catch let error as GoogleSignInError {
            throw error
        } catch {
            throw GoogleSignInError.network(error)
        }
    }

    /// Vincula una cuenta de Google al usuario **ya autenticado** (no es un
    /// login: el ID token solo aporta el `google_id`, la identidad viene de
    /// la sesión). No toca email ni username.
    func linkGoogleAccount(idToken: String) async throws {
        do {
            let output = try await client.link_google_account_api_v1_auth_me_google_post(
                .init(body: .json(.init(id_token: idToken)))
            )
            switch output {
            case .ok(let ok):
                state = .signedIn(try ok.body.json)
            case .unauthorized:
                throw ProfileError.sessionExpired
            case .conflict:
                throw ProfileError.googleAlreadyLinked
            case .unprocessableContent:
                throw ProfileError.invalidData
            case .undocumented(let statusCode, _):
                throw ProfileError.unexpected(statusCode)
            }
        } catch let error as ProfileError {
            throw error
        } catch {
            throw ProfileError.network(error)
        }
    }

    /// Desvincula Google del usuario autenticado. El servidor rechaza si es
    /// la única forma de acceso (sin contraseña) — la app ya oculta el botón
    /// en ese caso, pero el error queda cubierto por si algo cambió entre
    /// medias (otra sesión, etc.).
    func unlinkGoogleAccount() async throws {
        do {
            let output = try await client.unlink_google_account_api_v1_auth_me_google_delete(.init())
            switch output {
            case .ok(let ok):
                state = .signedIn(try ok.body.json)
            case .unauthorized:
                throw ProfileError.sessionExpired
            case .conflict:
                throw ProfileError.googleOnlyAccess
            case .undocumented(let statusCode, _):
                throw ProfileError.unexpected(statusCode)
            }
        } catch let error as ProfileError {
            throw error
        } catch {
            throw ProfileError.network(error)
        }
    }

    /// Cambia la contraseña del usuario autenticado, o la pone por primera
    /// vez si la cuenta se creó puramente por Google. `currentPassword` es
    /// `nil` solo en ese segundo caso — el servidor decide si hace falta
    /// según si la cuenta ya tenía una, no la app.
    func changePassword(currentPassword: String?, newPassword: String) async throws {
        do {
            let output = try await client.change_password_api_v1_auth_me_password_post(
                .init(body: .json(.init(
                    current_password: currentPassword,
                    new_password: newPassword
                )))
            )
            switch output {
            case .noContent:
                // 204: no trae el usuario actualizado, pero `has_password`
                // puede haber cambiado (alta de contraseña en cuenta
                // solo-Google) — sin refrescar, la app se quedaría creyendo
                // que la cuenta sigue sin contraseña.
                state = .signedIn(try await fetchProfile())
            case .unauthorized:
                throw PasswordChangeError.wrongCurrentPassword
            case .unprocessableContent:
                throw PasswordChangeError.invalidData
            case .undocumented(let statusCode, _):
                throw PasswordChangeError.unexpected(statusCode)
            }
        } catch let error as PasswordChangeError {
            throw error
        } catch {
            throw PasswordChangeError.network(error)
        }
    }

    /// Quita la contraseña de la cuenta, que vuelve a depender solo de
    /// Google. El servidor rechaza si no hay Google vinculado (se quedaría
    /// sin ninguna forma de entrar).
    func removePassword() async throws {
        do {
            let output = try await client.remove_password_api_v1_auth_me_password_delete(.init())
            switch output {
            case .noContent:
                state = .signedIn(try await fetchProfile())
            case .unauthorized:
                throw PasswordChangeError.sessionExpired
            case .conflict:
                throw PasswordChangeError.passwordOnlyAccess
            case .undocumented(let statusCode, _):
                throw PasswordChangeError.unexpected(statusCode)
            }
        } catch let error as PasswordChangeError {
            throw error
        } catch {
            throw PasswordChangeError.network(error)
        }
    }

    /// Registra un usuario nuevo y, si va bien, inicia sesión automáticamente.
    ///
    /// El endpoint de registro no devuelve tokens (solo el usuario creado), así
    /// que encadenamos un `logIn` con las mismas credenciales para dejar a la
    /// persona directamente dentro de la app.
    ///
    /// - Throws: siempre un `RegisterError`, listo para pintar en la pantalla.
    func register(username: String, email: String, password: String) async throws {
        do {
            let output = try await client.register_api_v1_auth_register_post(
                .init(body: .json(.init(username: username, email: email, password: password)))
            )
            switch output {
            case .created:
                try await logIn(usernameOrEmail: username, password: password)
            case .conflict:
                throw RegisterError.alreadyTaken
            case .unprocessableContent:
                throw RegisterError.invalidData
            case .undocumented(let statusCode, _):
                throw RegisterError.unexpected(statusCode)
            }
        } catch let error as RegisterError {
            throw error
        } catch is LoginError {
            // La cuenta se creó, pero el auto-login falló. Que inicie sesión
            // a mano desde la pantalla de login.
            throw RegisterError.registeredButLoginFailed
        } catch {
            throw RegisterError.network(error)
        }
    }

    /// Edita los campos de perfil presentes (`nil` = no tocar ese campo; PATCH
    /// real, igual que en discografía). No toca email/contraseña/avatar.
    ///
    /// `username` es un caso especial: el servidor solo lo acepta si la
    /// cuenta todavía tiene el username provisional de un alta por Google
    /// (`username_is_default == true`, ver `User+Presentation.swift`); si no,
    /// responde `409` y aquí se traduce en `ProfileError.usernameLocked`.
    func updateProfile(
        username: String? = nil,
        fullName: String? = nil,
        country: String? = nil,
        city: String? = nil,
        birthDate: String? = nil,
        themePreference: Components.Schemas.ThemePreference? = nil
    ) async throws {
        do {
            let output = try await client.update_me_api_v1_auth_me_patch(
                .init(body: .json(.init(
                    username: username,
                    full_name: fullName,
                    country: country,
                    city: city,
                    birth_date: birthDate,
                    theme_preference: themePreference
                )))
            )
            switch output {
            case .ok(let ok):
                let user = try ok.body.json
                applyTheme(from: user)
                state = .signedIn(user)
            case .unauthorized:
                throw ProfileError.sessionExpired
            case .conflict(let conflict):
                let detail = (try? conflict.body.json.detail) ?? ""
                throw detail == "username_already_set" ? ProfileError.usernameLocked : ProfileError.usernameTaken
            case .unprocessableContent:
                throw ProfileError.invalidData
            case .undocumented(let statusCode, _):
                throw ProfileError.unexpected(statusCode)
            }
        } catch let error as ProfileError {
            throw error
        } catch {
            throw ProfileError.network(error)
        }
    }

    /// Sube (o sustituye) el avatar del usuario autenticado.
    func uploadAvatar(data: Data, mimeType: String, filename: String) async throws {
        do {
            let output = try await client.uploadAvatar(data: data, mimeType: mimeType, filename: filename)
            switch output {
            case .ok(let ok):
                state = .signedIn(try ok.body.json)
            case .unauthorized:
                throw ProfileError.sessionExpired
            case .contentTooLarge:
                throw ProfileError.imageTooLarge
            case .unprocessableContent:
                throw ProfileError.invalidData
            case .undocumented(let statusCode, _):
                throw ProfileError.unexpected(statusCode)
            }
        } catch let error as ProfileError {
            throw error
        } catch {
            throw ProfileError.network(error)
        }
    }

    /// Borra el avatar del usuario autenticado, si tenía uno.
    func deleteAvatar() async throws {
        do {
            let output = try await client.delete_avatar_api_v1_auth_me_avatar_delete(.init())
            switch output {
            case .ok(let ok):
                state = .signedIn(try ok.body.json)
            case .unauthorized:
                throw ProfileError.sessionExpired
            case .undocumented(let statusCode, _):
                throw ProfileError.unexpected(statusCode)
            }
        } catch let error as ProfileError {
            throw error
        } catch {
            throw ProfileError.network(error)
        }
    }

    /// Cierra la sesión: intenta revocar en el servidor y limpia el local.
    ///
    /// La revocación es *best-effort*: aunque falle (sin red), la sesión local
    /// se borra igual. Lo que nunca puede pasar es quedarnos "medio dentro".
    func logOut() async {
        // 1) Cierre local INMEDIATO, sin tocar la red. Estas operaciones son
        //    locales (Keychain, ~ms), así que la UI responde al instante
        //    aunque el servidor esté caído o lento.
        let tokens = try? await tokenStore.load()
        try? await tokenStore.clear()
        state = .signedOut

        // 2) Revocación en el servidor: best-effort, en segundo plano. No
        //    bloquea el cierre de sesión; si no hay red, da igual, ya estamos
        //    fuera. Lleva el token capturado porque el Keychain ya está limpio.
        if let tokens {
            Task { await Client.revokeSession(tokens, environment: environment) }
        }
    }

    // MARK: - Privado

    /// Aplica la preferencia de apariencia guardada en el servidor a
    /// `UserDefaults` (la fuente de verdad de `@AppStorage("appearance")`).
    private func applyTheme(from user: User) {
        let theme = AppTheme(from: user.theme_preference)
        UserDefaults.standard.set(theme.rawValue, forKey: "appearance")
    }

    private func fetchProfile() async throws -> User {
        let output = try await client.me_api_v1_auth_me_get(.init())
        switch output {
        case .ok(let ok):
            return try ok.body.json
        case .unauthorized:
            throw AuthError.sessionExpired
        case .undocumented(let statusCode, _):
            throw AuthError.unexpectedStatus(statusCode)
        }
    }
}
