//
//  TokenRefresher.swift
//  OmmadawnAPI
//
//  Renueva la sesión contra `POST /api/v1/auth/refresh`, coordinando que
//  varias peticiones caducadas a la vez NO disparen varias renovaciones.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

// MARK: - Errores de sesión

public enum AuthError: Error, Sendable, Equatable {
    /// No hay tokens guardados: hay que iniciar sesión.
    case notAuthenticated
    /// El refresh token ya no vale (caducado, revocado o reutilizado), o la
    /// cuenta está desactivada. Hay que volver a iniciar sesión.
    case sessionExpired
    /// La API respondió algo que el contrato no contempla para este caso.
    case unexpectedStatus(Int)
}

// MARK: - Renovador

/// Punto único de renovación de la sesión.
///
/// Es un `actor` para **serializar** las renovaciones. La API **rota** el
/// refresh token en cada uso: si dos peticiones renovasen a la vez, la segunda
/// enviaría un token ya invalidado y el servidor invalidaría toda la familia
/// de tokens — expulsando al usuario. Aquí solo se renueva **una vez** y el
/// resto de llamadas comparten ese resultado.
public actor TokenRefresher {
    private let tokenStore: TokenStore

    /// Cliente **sin** el middleware de auth.
    ///
    /// Es deliberado: si el refresco pasara por el middleware, un `401` al
    /// renovar dispararía otra renovación, y así indefinidamente.
    private let client: Client

    /// Renovación en curso, si la hay (patrón *single-flight*).
    private var inFlight: Task<AuthTokens, Error>?

    /// Margen antes de la caducidad para renovar con antelación (cubre latencia
    /// de red y desfase de reloj).
    private static let refreshBuffer: TimeInterval = 60

    public init(tokenStore: TokenStore = .shared, environment: APIEnvironment = .development) {
        self.tokenStore = tokenStore
        self.client = Client(
            serverURL: environment.baseURL,
            configuration: .ommadawn,
            transport: URLSessionTransport()
        )
    }

    /// Tokens actuales, o `nil` si no hay sesión.
    public func currentTokens() async throws -> AuthTokens? {
        try await tokenStore.load()
    }

    /// Devuelve un access token **válido**, renovando de forma **proactiva** si
    /// está a punto de caducar (dentro de `refreshBuffer`). Coordinado igual que
    /// la renovación reactiva (single-flight). Si no se conoce la caducidad
    /// (`expiresAt == nil`), no renueva por adelantado: queda la red del `401`.
    public func validAccessToken() async throws -> String {
        guard let tokens = try await tokenStore.load() else {
            throw AuthError.notAuthenticated
        }
        if let expiresAt = tokens.expiresAt,
           Date() >= expiresAt.addingTimeInterval(-Self.refreshBuffer) {
            return try await refresh(staleAccessToken: tokens.accessToken).accessToken
        }
        return tokens.accessToken
    }

    /// Renueva la sesión y devuelve el par nuevo.
    ///
    /// - Parameter staleAccessToken: el access token que provocó el `401`.
    ///   Sirve para detectar que **otra** petición ya renovó mientras
    ///   esperábamos: en ese caso no se renueva otra vez.
    public func refresh(staleAccessToken: String) async throws -> AuthTokens {
        // ¿Alguien renovó ya? Entonces lo guardado es más nuevo que lo que
        // teníamos y basta con reutilizarlo.
        if let stored = try await tokenStore.load(), stored.accessToken != staleAccessToken {
            return stored
        }

        // ¿Hay una renovación en vuelo? Nos colgamos de ella.
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task<AuthTokens, Error> { try await self.performRefresh() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    /// Cierra la sesión en local (borra los tokens del Keychain).
    public func clearSession() async throws {
        try await tokenStore.clear()
    }

    // MARK: Privado

    private func performRefresh() async throws -> AuthTokens {
        guard let current = try await tokenStore.load() else {
            throw AuthError.notAuthenticated
        }

        let output = try await client.refresh_api_v1_auth_refresh_post(
            .init(body: .json(.init(refresh_token: current.refreshToken)))
        )

        switch output {
        case .ok(let ok):
            let pair = try ok.body.json
            // Guardamos SIEMPRE el par nuevo: el refresh token anterior ya no
            // vale (rotación). Es una única escritura atómica.
            let tokens = AuthTokens(pair: pair)
            try await tokenStore.save(tokens)
            return tokens

        case .unauthorized, .forbidden:
            // Refresh inválido/caducado/reutilizado, o cuenta desactivada.
            // La sesión local ya no sirve para nada: se limpia.
            try? await tokenStore.clear()
            throw AuthError.sessionExpired

        case .unprocessableContent:
            throw AuthError.unexpectedStatus(422)

        case .undocumented(let statusCode, _):
            throw AuthError.unexpectedStatus(statusCode)
        }
    }
}
