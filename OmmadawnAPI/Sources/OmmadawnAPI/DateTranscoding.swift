//
//  DateTranscoding.swift
//  OmmadawnAPI
//
//  Traducción de fechas entre la API y Swift.
//
//  Por qué existe este archivo: el contrato declara `created_at` como
//  `format: date-time`, pero eso admite variantes. La API (Python/FastAPI)
//  emite MICROSEGUNDOS:
//
//      2026-07-24T14:35:58.101031Z
//
//  y el decodificador por defecto de swift-openapi-runtime (ISO8601 sin
//  fracciones de segundo) lo rechaza con "Expected date string to be
//  ISO8601-formatted". Ambos lados son RFC3339 válidos; simplemente no se
//  entienden. Esto se arregla en el cliente, sin tocar la API.
//

import Foundation
import OpenAPIRuntime

/// Convierte fechas ISO8601 tolerando las variantes que manda la API.
///
/// Usa `Date.ISO8601FormatStyle` (no `ISO8601DateFormatter`) por dos motivos:
/// acepta fracciones de segundo de cualquier longitud —milisegundos y
/// microsegundos— además de las fechas sin fracción y los offsets no-UTC; y
/// es un `struct` `Sendable`, apto para Swift 6 sin trucos de concurrencia.
struct FlexibleISO8601DateTranscoder: DateTranscoder {
    /// Al enviar fechas usamos el ISO8601 estándar en UTC.
    /// (Hoy ningún endpoint recibe fechas, pero conviene que sea correcto.)
    func encode(_ date: Date) throws -> String {
        date.formatted(.iso8601)
    }

    func decode(_ string: String) throws -> Date {
        do {
            return try Date(string, strategy: .iso8601)
        } catch {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "Fecha no reconocida como ISO8601: \(string)",
                    underlyingError: error
                )
            )
        }
    }
}

extension Configuration {
    /// Configuración común de los clientes de esta API.
    static var ommadawn: Configuration {
        Configuration(dateTranscoder: FlexibleISO8601DateTranscoder())
    }
}
