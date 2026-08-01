//
//  APIClient.swift
//  OmmadawnAPI
//
//  Código HECHO A MANO (lo poco que no genera el plugin): configuración de
//  entorno y una forma cómoda de construir el `Client` generado.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Entornos contra los que puede correr la app.
///
/// `rawValue` String para persistirlo en `UserDefaults`.
public enum APIEnvironment: String, Sendable, CaseIterable {
    /// API local en el Mac. En el simulador funciona por loopback (127.0.0.1).
    /// En dispositivo físico habría que usar la IP del Mac en la LAN o cambiar
    /// al entorno de pre-producción.
    case development

    /// Servidor de pre-producción desplegado. Requiere conexión a internet.
    case preproduction

    /// Origen del servidor: SOLO esquema + host + puerto.
    /// Las rutas del contrato ya incluyen `/api/v1/...`, por eso no va aquí.
    public var baseURL: URL {
        switch self {
        case .development:
            URL(string: "http://127.0.0.1:8000")!
        case .preproduction:
            URL(string: "https://api.pre.ommadawn.es")!
        }
    }

    public var displayName: String {
        switch self {
        case .development:   "Local (127.0.0.1:8000)"
        case .preproduction: "Pre-producción (api.pre.ommadawn.es)"
        }
    }
}

public extension Client {
    /// Crea el cliente generado apuntando al entorno indicado, usando
    /// URLSession como transporte.
    ///
    /// Uso desde la app:
    /// ```swift
    /// let client = Client(environment: .development)
    /// let response = try await client.health_health_get()
    /// ```
    init(environment: APIEnvironment = .development) {
        self.init(
            serverURL: environment.baseURL,
            configuration: .ommadawn,
            transport: URLSessionTransport()
        )
    }

    /// Cliente **autenticado**: añade el token a las peticiones protegidas y
    /// renueva la sesión automáticamente ante un `401`.
    ///
    /// - Important: créalo **una sola vez** y compártelo. Cada instancia
    ///   coordina sus propias renovaciones, así que tener varias reintroduce
    ///   justo la carrera que el `TokenRefresher` evita.
    static func authenticated(
        environment: APIEnvironment = .development,
        refresher: TokenRefresher? = nil
    ) -> Client {
        let refresher = refresher ?? TokenRefresher(environment: environment)
        return Client(
            serverURL: environment.baseURL,
            configuration: .ommadawn,
            transport: URLSessionTransport(),
            middlewares: [AuthMiddleware(refresher: refresher)]
        )
    }

    /// Revoca la sesión en el servidor (best-effort) con unos tokens dados,
    /// **sin depender del almacén**. Pensado para el logout: se llama después
    /// de haber limpiado el Keychain, así que lleva el access token a mano.
    static func revokeSession(
        _ tokens: AuthTokens,
        environment: APIEnvironment = .development
    ) async {
        let client = Client(
            serverURL: environment.baseURL,
            configuration: .ommadawn,
            transport: URLSessionTransport(),
            middlewares: [BearerMiddleware(accessToken: tokens.accessToken)]
        )
        _ = try? await client.logout_api_v1_auth_logout_post(
            .init(body: .json(.init(refresh_token: tokens.refreshToken)))
        )
    }
}
