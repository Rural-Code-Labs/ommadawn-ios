//
//  ForumStore.swift
//  ommadawn
//
//  Dueño de las llamadas al foro (Fase 7). Mismo patrón que
//  `DiscographyStore`: envuelve el `Client` de `AuthSession`, sin estado
//  propio observable.
//

import Foundation
import OmmadawnAPI

/// Motivos por los que una llamada al foro puede fallar.
enum ForumError: Error {
    case notFound
    case sessionExpired    // 401
    case emailNotVerified  // 403 al crear un hilo o comentar — falta verificar el email
    case subforumRestricted // 403 al crear un hilo — el subforo es admin_only y no eres admin
    case forbidden         // 403 al cambiar el estado — no es admin
    case invalidData       // 422 — p. ej. entity_id no corresponde a ningún disco/edición
    case unexpected(Int)
    case network(Error)
}

struct ForumStore {
    private let client: Client

    init(client: Client) {
        self.client = client
    }

    /// Lista los subforos (secciones del foro), ordenados por posición. Hoy
    /// solo existe "Discusiones", pero el modelo ya soporta más.
    func fetchSubforums() async throws -> [SubforumSummary] {
        do {
            let output = try await client.list_subforums_api_v1_forum_subforums_get(.init())
            switch output {
            case .ok(let r): return try r.body.json
            case .undocumented(let c, _): throw ForumError.unexpected(c)
            }
        } catch let e as ForumError { throw e }
        catch { throw ForumError.network(error) }
    }

    /// Lista hilos paginados, más recientes primero. `subforumId` filtra por
    /// subforo; `entityType`+`entityId` filtran por disco/edición concreto;
    /// `status` filtra por estado (p. ej. `.open` para la cola de Inicio).
    /// `limit`/`offset` paginan; `total` en la respuesta es el número de
    /// hilos que cumplen el filtro sin paginar.
    func fetchThreads(
        subforumId: Int? = nil,
        entityType: ForumEntityType? = nil,
        entityId: Int? = nil,
        status: ForumThreadStatus? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> ForumThreadPage {
        do {
            let output = try await client.list_threads_api_v1_forum_threads_get(
                .init(query: .init(subforum_id: subforumId, entity_type: entityType, entity_id: entityId, status: status, limit: limit, offset: offset))
            )
            switch output {
            case .ok(let r): return try r.body.json
            case .unprocessableContent: throw ForumError.invalidData
            case .undocumented(let c, _): throw ForumError.unexpected(c)
            }
        } catch let e as ForumError { throw e }
        catch { throw ForumError.network(error) }
    }

    /// Detalle de un hilo, con todos sus comentarios.
    func fetchThread(id: Int) async throws -> ForumThreadDetail {
        do {
            let output = try await client.get_thread_api_v1_forum_threads__thread_id__get(
                .init(path: .init(thread_id: id))
            )
            switch output {
            case .ok(let r): return try r.body.json
            case .notFound: throw ForumError.notFound
            case .unprocessableContent: throw ForumError.invalidData
            case .undocumented(let c, _): throw ForumError.unexpected(c)
            }
        } catch let e as ForumError { throw e }
        catch { throw ForumError.network(error) }
    }

    /// Crea un hilo dentro de `subforumId` (obligatorio: todo hilo vive en un
    /// subforo). `entityType`/`entityId` opcionales: a qué disco/edición se
    /// refiere dentro de ese subforo, `.discography` para un tema general, o
    /// ninguno de los dos para un tema sin tema (la app todavía no expone
    /// esta última opción).
    func createThread(
        subforumId: Int,
        title: String,
        body: String,
        entityType: ForumEntityType? = nil,
        entityId: Int? = nil
    ) async throws -> ForumThreadDetail {
        do {
            let output = try await client.create_thread_api_v1_forum_threads_post(
                .init(body: .json(.init(title: title, body: body, subforum_id: subforumId, entity_type: entityType, entity_id: entityId)))
            )
            switch output {
            case .created(let r): return try r.body.json
            case .unauthorized: throw ForumError.sessionExpired
            case .forbidden(let r):
                let detail = (try? r.body.json.detail) ?? ""
                throw detail == "email_not_verified" ? ForumError.emailNotVerified : ForumError.subforumRestricted
            case .notFound: throw ForumError.notFound
            case .unprocessableContent: throw ForumError.invalidData
            case .undocumented(let c, _): throw ForumError.unexpected(c)
            }
        } catch let e as ForumError { throw e }
        catch { throw ForumError.network(error) }
    }

    /// Añade un comentario a un hilo.
    func addComment(threadID: Int, body: String) async throws -> ForumComment {
        do {
            let output = try await client.add_comment_api_v1_forum_threads__thread_id__comments_post(
                .init(path: .init(thread_id: threadID), body: .json(.init(body: body)))
            )
            switch output {
            case .created(let r): return try r.body.json
            case .unauthorized: throw ForumError.sessionExpired
            case .forbidden: throw ForumError.emailNotVerified
            case .notFound: throw ForumError.notFound
            case .unprocessableContent: throw ForumError.invalidData
            case .undocumented(let c, _): throw ForumError.unexpected(c)
            }
        } catch let e as ForumError { throw e }
        catch { throw ForumError.network(error) }
    }

    /// Cambia el estado de un hilo (solo admin). Aplicar el cambio propuesto
    /// en el catálogo sigue siendo manual, con las pantallas de edición que
    /// ya existen — esto solo marca el hilo.
    func updateThreadStatus(id: Int, status: ForumThreadStatus, resolutionNote: String? = nil) async throws -> ForumThreadDetail {
        do {
            let output = try await client.update_thread_status_api_v1_forum_threads__thread_id__patch(
                .init(path: .init(thread_id: id), body: .json(.init(status: status, resolution_note: resolutionNote)))
            )
            switch output {
            case .ok(let r): return try r.body.json
            case .unauthorized: throw ForumError.sessionExpired
            case .forbidden: throw ForumError.forbidden
            case .notFound: throw ForumError.notFound
            case .unprocessableContent: throw ForumError.invalidData
            case .undocumented(let c, _): throw ForumError.unexpected(c)
            }
        } catch let e as ForumError { throw e }
        catch { throw ForumError.network(error) }
    }
}
