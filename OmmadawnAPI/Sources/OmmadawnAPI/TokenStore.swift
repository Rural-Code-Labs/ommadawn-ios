//
//  TokenStore.swift
//  OmmadawnAPI
//
//  Almacén seguro del par de tokens de sesión, sobre Keychain Services.
//
//  Contexto: el Keychain NO es un archivo de la app; es una base de datos
//  cifrada que gestiona el sistema (`securityd`) fuera de nuestro sandbox.
//  Cada operación es una llamada IPC SÍNCRONA que bloquea el hilo, por eso
//  todo esto vive dentro de un `actor` (nunca en el @MainActor).
//

import Foundation
import Security

// MARK: - Modelo

/// El par de tokens que emite la API (`POST /auth/login` y `/auth/refresh`),
/// con la caducidad del access token.
///
/// El contrato expone `expires_in` (segundos), así que guardamos el momento de
/// caducidad para poder renovar **proactivamente** antes de que expire. Se
/// mantiene además la renovación *reactiva* (ante un `401`) como red de seguridad.
public struct AuthTokens: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String

    /// Momento en que caduca el access token. Opcional: los tokens guardados
    /// por versiones anteriores no lo tienen → se trata como "desconocido"
    /// (sin refresco proactivo; sigue valiendo el reactivo ante `401`).
    public let expiresAt: Date?

    public init(accessToken: String, refreshToken: String, expiresAt: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// Construye los tokens desde el par de la API, calculando la caducidad
    /// como "ahora + `expires_in` segundos".
    public init(pair: Components.Schemas.TokenPair) {
        self.init(
            accessToken: pair.access_token,
            refreshToken: pair.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(pair.expires_in))
        )
    }
}

// MARK: - Error

/// Envuelve el `OSStatus` crudo del Keychain con su mensaje del sistema.
public struct KeychainError: Error, CustomStringConvertible {
    public let status: OSStatus

    public var description: String {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "desconocido"
        return "KeychainError(\(status)): \(message)"
    }
}

// MARK: - Almacén

/// Guarda, lee y borra el par de tokens.
///
/// Es un `actor` por dos motivos: mantener las llamadas `SecItem*` fuera del
/// hilo principal, y **serializar** los accesos (dos renovaciones simultáneas
/// no pueden pisarse entre sí).
public actor TokenStore {
    public static let shared = TokenStore()

    /// Todos los items de sesión comparten `service`: así el logout puede
    /// borrarlos TODOS de una sola llamada, sin dejar olvidado el refresh token.
    private let service: String

    /// Los DOS tokens se guardan en **un único item** (un JSON), no en dos.
    ///
    /// Es deliberado: en cada login/refresh la API devuelve un par nuevo y
    /// rota el refresh token. Con un solo item, actualizarlos es **una sola
    /// escritura atómica**. Con dos items, un fallo entre ambas escrituras
    /// dejaría tokens descasados y al usuario fuera de la sesión.
    private let account = "auth_tokens"

    /// Solo descifrable con el dispositivo desbloqueado, y atado a ESTE
    /// dispositivo (no viaja en backups). Recomendado para tokens.
    private let accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    public init(service: String = "com.ruralcodelabs.ommadawn.auth") {
        self.service = service
    }

    /// Identidad del item. Para `kSecClassGenericPassword`, la unicidad la
    /// determinan service + account (+ grupo de acceso). Sin flags de retorno
    /// ni accesibilidad: cada llamada usa su propio diccionario.
    private var identityQuery: [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        #if os(macOS)
        // En macOS hay que pedir explícitamente el keychain con protección de
        // datos (el de estilo iOS); si no, se usa el legacy basado en archivo.
        query[kSecUseDataProtectionKeychain] = true
        #endif
        return query
    }

    // MARK: Guardar

    /// Guarda el par de tokens (crea o actualiza).
    ///
    /// Patrón *add-or-update*: nunca borrar-y-añadir, que abre una ventana de
    /// carrera en la que la sesión no existe.
    public func save(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)

        var addQuery = identityQuery
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = accessibility

        switch SecItemAdd(addQuery as CFDictionary, nil) {
        case errSecSuccess:
            return

        case errSecDuplicateItem:
            // Ya existía: actualizamos SOLO el valor. El diccionario de update
            // no lleva ni `kSecClass` ni flags de búsqueda (daría errSecParam).
            let updates: [CFString: Any] = [kSecValueData: data]
            let status = SecItemUpdate(identityQuery as CFDictionary, updates as CFDictionary)
            guard status == errSecSuccess else { throw KeychainError(status: status) }

        case let status:
            throw KeychainError(status: status)
        }
    }

    // MARK: Leer

    /// Devuelve los tokens guardados, o `nil` si no hay sesión.
    public func load() throws -> AuthTokens? {
        var query = identityQuery
        // Sin `kSecReturnData` el sistema devuelve éxito… y `nil`. Clásico.
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError(status: errSecParam) }
            return try JSONDecoder().decode(AuthTokens.self, from: data)

        case errSecItemNotFound:
            // "No hay sesión" es un estado legítimo, no un error.
            return nil

        case errSecInteractionNotAllowed:
            // Dispositivo bloqueado: el item existe pero ahora no es legible.
            // Reintentar más tarde; JAMÁS borrarlo en respuesta a esto.
            throw KeychainError(status: status)

        case let status:
            throw KeychainError(status: status)
        }
    }

    // MARK: Borrar (logout)

    /// Borra **todos** los items de sesión de este `service`.
    ///
    /// Ojo: `SecItemDelete` usa `kSecMatchLimitAll` por defecto. Aquí eso es
    /// justo lo que queremos (limpieza total al cerrar sesión), pero en otros
    /// contextos una consulta poco específica borraría de más.
    public func clear() throws {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        #if os(macOS)
        query[kSecUseDataProtectionKeychain] = true
        #endif

        let status = SecItemDelete(query as CFDictionary)
        // Que no hubiera nada que borrar es un final válido, no un error.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}
