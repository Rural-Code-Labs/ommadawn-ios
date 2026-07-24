//
//  AuthMiddleware.swift
//  OmmadawnAPI
//
//  Middleware que centraliza la autenticación: añade el `Authorization:
//  Bearer` a las peticiones protegidas y, ante un 401, renueva la sesión y
//  reintenta UNA vez.
//
//  La gracia está en que esto vive en UN solo sitio: ninguna pantalla tiene
//  que saber nada de tokens ni de reintentos.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

public struct AuthMiddleware: ClientMiddleware {
    private let refresher: TokenRefresher

    public init(refresher: TokenRefresher) {
        self.refresher = refresher
    }

    /// Operaciones que NO llevan token.
    ///
    /// Es una lista de exclusión a propósito: así, cuando la API publique
    /// endpoints nuevos (discografía, conciertos…), quedan protegidos **por
    /// defecto**. Olvidarse de añadir uno falla del lado seguro.
    private static let publicOperations: Set<String> = [
        "health_health_get",
        "login_api_v1_auth_login_post",
        "register_api_v1_auth_register_post",
        "refresh_api_v1_auth_refresh_post",
    ]

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard !Self.publicOperations.contains(operationID) else {
            return try await next(request, body, baseURL)
        }

        // Endpoint protegido sin sesión: fallamos ya, sin gastar una petición.
        guard let tokens = try await refresher.currentTokens() else {
            throw AuthError.notAuthenticated
        }

        var authorized = request
        authorized.headerFields[.authorization] = "Bearer \(tokens.accessToken)"

        let (response, responseBody) = try await next(authorized, body, baseURL)

        guard response.status == .unauthorized else {
            return (response, responseBody)
        }

        // 401: el access token caducó. Para reintentar hace falta poder
        // reenviar el cuerpo, y un HTTPBody puede ser de un solo uso.
        guard Self.isReplayable(body) else {
            return (response, responseBody)
        }

        // Renovar (coalescido) y reintentar UNA sola vez. Si la renovación
        // falla, propaga `AuthError.sessionExpired` y la app manda a login.
        let renewed = try await refresher.refresh(staleAccessToken: tokens.accessToken)

        var retried = request
        retried.headerFields[.authorization] = "Bearer \(renewed.accessToken)"
        return try await next(retried, body, baseURL)
    }

    /// ¿Se puede volver a enviar este cuerpo?
    ///
    /// Sin cuerpo (GET) siempre se puede. Con cuerpo, solo si su secuencia
    /// admite varias iteraciones; si es `.single`, reintentar lo enviaría
    /// vacío o fallaría, así que devolvemos el 401 tal cual.
    private static func isReplayable(_ body: HTTPBody?) -> Bool {
        guard let body else { return true }
        if case .multiple = body.iterationBehavior { return true }
        return false
    }
}
