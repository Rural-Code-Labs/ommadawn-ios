//
//  DiscographyStore.swift
//  ommadawn
//
//  Dueño de las llamadas al catálogo (discografía). Reutiliza el Client
//  autenticado de AuthSession en vez de crear uno propio: aunque leer el
//  catálogo sea público, así queda listo para las acciones de admin
//  (crear/editar obras) que sí necesitan el Bearer.
//

import Foundation
import OmmadawnAPI

/// Motivos por los que una llamada al catálogo puede fallar.
enum DiscographyError: Error {
    case notFound
    case unexpected(Int)
    case network(Error)
}

/// Sin estado propio observable (solo envuelve al `Client`): un `struct` de
/// funciones, no una clase. A diferencia de `AuthSession`, no hay nada aquí
/// que una vista necesite observar.
struct DiscographyStore {
    private let client: Client

    init(client: Client) {
        self.client = client
    }

    /// Lista obras del catálogo, opcionalmente filtradas por tipo.
    func fetchReleases(type: ReleaseType? = nil) async throws -> [Release] {
        do {
            let output = try await client.list_releases_api_v1_discography_releases_get(
                .init(query: .init(_type: type))
            )
            switch output {
            case .ok(let ok):
                return try ok.body.json
            case .unprocessableContent:
                // El único query param es `type`, ya tipado como ReleaseType:
                // no debería poder llegar aquí, pero el Output lo contempla.
                throw DiscographyError.unexpected(422)
            case .undocumented(let statusCode, _):
                throw DiscographyError.unexpected(statusCode)
            }
        } catch let error as DiscographyError {
            throw error
        } catch {
            throw DiscographyError.network(error)
        }
    }

    /// Detalle de una obra, con sus ediciones, temas e imágenes.
    func fetchRelease(id: Int) async throws -> Release {
        do {
            let output = try await client.get_release_api_v1_discography_releases__release_id__get(
                .init(path: .init(release_id: id))
            )
            switch output {
            case .ok(let ok):
                return try ok.body.json
            case .notFound:
                throw DiscographyError.notFound
            case .unprocessableContent:
                throw DiscographyError.unexpected(422)
            case .undocumented(let statusCode, _):
                throw DiscographyError.unexpected(statusCode)
            }
        } catch let error as DiscographyError {
            throw error
        } catch {
            throw DiscographyError.network(error)
        }
    }
}
