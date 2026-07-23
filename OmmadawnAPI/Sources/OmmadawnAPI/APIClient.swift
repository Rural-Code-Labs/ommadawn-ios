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
/// De momento solo `development` (la API local con `uvicorn`). Cuando exista
/// un servidor desplegado, se añade `production` con su URL.
public enum APIEnvironment: Sendable {
    /// API local en el Mac. En el simulador funciona por loopback (127.0.0.1).
    /// En dispositivo físico habría que usar la IP del Mac en la LAN.
    case development

    /// Origen del servidor: SOLO esquema + host + puerto.
    /// Las rutas del contrato ya incluyen `/api/v1/...`, por eso no va aquí.
    var baseURL: URL {
        switch self {
        case .development:
            URL(string: "http://127.0.0.1:8000")!
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
            transport: URLSessionTransport()
        )
    }
}
