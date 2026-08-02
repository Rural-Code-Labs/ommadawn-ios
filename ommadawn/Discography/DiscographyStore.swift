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
    case forbidden     // 403 — el endpoint exige admin y el usuario no lo es
    case imageTooLarge // 413 — imagen supera el límite del servidor
    case unexpected(Int)
    case network(Error)
}

/// DTO intermedio: los datos del formulario de edición, independiente de los
/// tipos generados. Lo construye `EditionEditView` y lo consume el store.
struct EditionPayload {
    var editionName: String = ""
    var country: String? = nil
    var label: String = ""
    var catalogNumber: String = ""
    var releaseDate: String? = nil     // "YYYY-MM-DD" o nil
    var format: EditionFormat? = nil
    var credits: String = ""
    var notes: String = ""
    var isPrimary: Bool = false
    var tracks: [EditableTrack] = []

    var trackPayloads: [Components.Schemas.TrackCreate] {
        tracks.enumerated().compactMap { index, track in
            let title = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return .init(position: index + 1, title: title, duration_seconds: track.durationSeconds)
        }
    }
}

/// Modelo local de tema para el formulario (sin ID de API: la posición es el índice).
struct EditableTrack: Identifiable {
    var id = UUID()
    var title: String = ""
    var durationText: String = ""  // "M:SS" o "H:MM:SS" como el usuario lo introduce

    var durationSeconds: Int? {
        let parts = durationText.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 2: return parts[0] * 60 + parts[1]
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default: return nil
        }
    }

    init(title: String = "", durationText: String = "") {
        self.title = title
        self.durationText = durationText
    }

    init(from track: Track) {
        self.title = track.title
        if let secs = track.duration_seconds {
            let h = secs / 3600
            let m = (secs % 3600) / 60
            let s = secs % 60
            self.durationText = h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%d:%02d", m, s)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trimmingCharacters(in: .whitespacesAndNewlines) }
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

    // MARK: - Escritura (require_admin)

    /// Crea una obra nueva en el catálogo.
    func createRelease(title: String, type: ReleaseType) async throws -> Release {
        do {
            let output = try await client.create_release_api_v1_discography_releases_post(
                .init(body: .json(.init(title: title, release_type: type)))
            )
            switch output {
            case .created(let created): return try created.body.json
            case .unauthorized: throw DiscographyError.forbidden
            case .forbidden: throw DiscographyError.forbidden
            case .unprocessableContent: throw DiscographyError.unexpected(422)
            case .undocumented(let code, _): throw DiscographyError.unexpected(code)
            }
        } catch let error as DiscographyError { throw error }
        catch { throw DiscographyError.network(error) }
    }

    /// Actualiza título y/o tipo de una obra existente.
    func updateRelease(id: Int, title: String, type: ReleaseType) async throws -> Release {
        do {
            let output = try await client.update_release_api_v1_discography_releases__release_id__patch(
                .init(path: .init(release_id: id), body: .json(.init(title: title, release_type: type)))
            )
            switch output {
            case .ok(let ok): return try ok.body.json
            case .unauthorized: throw DiscographyError.forbidden
            case .forbidden: throw DiscographyError.forbidden
            case .notFound: throw DiscographyError.notFound
            case .unprocessableContent: throw DiscographyError.unexpected(422)
            case .undocumented(let code, _): throw DiscographyError.unexpected(code)
            }
        } catch let error as DiscographyError { throw error }
        catch { throw DiscographyError.network(error) }
    }

    /// Elimina una obra y todas sus ediciones.
    func deleteRelease(id: Int) async throws {
        do {
            let output = try await client.delete_release_api_v1_discography_releases__release_id__delete(
                .init(path: .init(release_id: id))
            )
            switch output {
            case .noContent: return
            case .unauthorized: throw DiscographyError.forbidden
            case .forbidden: throw DiscographyError.forbidden
            case .notFound: throw DiscographyError.notFound
            case .unprocessableContent: throw DiscographyError.unexpected(422)
            case .undocumented(let code, _): throw DiscographyError.unexpected(code)
            }
        } catch let error as DiscographyError { throw error }
        catch { throw DiscographyError.network(error) }
    }

    // MARK: - Ediciones (require_admin)

    func createEdition(releaseID: Int, data: EditionPayload) async throws -> Edition {
        do {
            let body = Components.Schemas.EditionCreate(
                country: data.country,
                label: data.label.nilIfEmpty,
                edition_name: data.editionName.nilIfEmpty,
                catalog_number: data.catalogNumber.nilIfEmpty,
                release_date: data.releaseDate,
                format: data.format,
                credits: data.credits.nilIfEmpty,
                notes: data.notes.nilIfEmpty,
                is_primary: data.isPrimary,
                tracks: data.trackPayloads
            )
            let output = try await client.create_edition_api_v1_discography_releases__release_id__editions_post(
                .init(path: .init(release_id: releaseID), body: .json(body))
            )
            switch output {
            case .created(let r): return try r.body.json
            case .unauthorized: throw DiscographyError.forbidden
            case .forbidden: throw DiscographyError.forbidden
            case .notFound: throw DiscographyError.notFound
            case .unprocessableContent: throw DiscographyError.unexpected(422)
            case .undocumented(let c, _): throw DiscographyError.unexpected(c)
            }
        } catch let e as DiscographyError { throw e }
        catch { throw DiscographyError.network(error) }
    }

    func updateEdition(releaseID: Int, editionID: Int, data: EditionPayload) async throws -> Edition {
        do {
            let body = Components.Schemas.EditionUpdate(
                country: data.country,
                label: data.label.nilIfEmpty,
                edition_name: data.editionName.nilIfEmpty,
                catalog_number: data.catalogNumber.nilIfEmpty,
                release_date: data.releaseDate,
                format: data.format,
                credits: data.credits.nilIfEmpty,
                notes: data.notes.nilIfEmpty,
                is_primary: data.isPrimary,
                tracks: data.trackPayloads
            )
            let output = try await client.update_edition_api_v1_discography_releases__release_id__editions__edition_id__patch(
                .init(path: .init(release_id: releaseID, edition_id: editionID), body: .json(body))
            )
            switch output {
            case .ok(let r): return try r.body.json
            case .unauthorized: throw DiscographyError.forbidden
            case .forbidden: throw DiscographyError.forbidden
            case .notFound: throw DiscographyError.notFound
            case .unprocessableContent: throw DiscographyError.unexpected(422)
            case .undocumented(let c, _): throw DiscographyError.unexpected(c)
            }
        } catch let e as DiscographyError { throw e }
        catch { throw DiscographyError.network(error) }
    }

    func deleteEdition(releaseID: Int, editionID: Int) async throws {
        do {
            let output = try await client.delete_edition_api_v1_discography_releases__release_id__editions__edition_id__delete(
                .init(path: .init(release_id: releaseID, edition_id: editionID))
            )
            switch output {
            case .noContent: return
            case .unauthorized: throw DiscographyError.forbidden
            case .forbidden: throw DiscographyError.forbidden
            case .notFound: throw DiscographyError.notFound
            case .unprocessableContent: throw DiscographyError.unexpected(422)
            case .undocumented(let c, _): throw DiscographyError.unexpected(c)
            }
        } catch let e as DiscographyError { throw e }
        catch { throw DiscographyError.network(error) }
    }

    // MARK: - Imágenes (require_admin)

    func uploadEditionImage(
        releaseID: Int,
        editionID: Int,
        data: Data,
        mimeType: String,
        filename: String,
        imageType: ReleaseImageType
    ) async throws -> ReleaseImage {
        do {
            let output = try await client.uploadEditionImage(
                releaseID: releaseID,
                editionID: editionID,
                data: data,
                mimeType: mimeType,
                filename: filename,
                imageType: imageType
            )
            switch output {
            case .created(let r): return try r.body.json
            case .unauthorized: throw DiscographyError.forbidden
            case .forbidden: throw DiscographyError.forbidden
            case .notFound: throw DiscographyError.notFound
            case .contentTooLarge: throw DiscographyError.imageTooLarge
            case .unprocessableContent: throw DiscographyError.unexpected(422)
            case .undocumented(let c, _): throw DiscographyError.unexpected(c)
            }
        } catch let e as DiscographyError { throw e }
        catch { throw DiscographyError.network(error) }
    }

    func deleteEditionImage(releaseID: Int, editionID: Int, imageID: Int) async throws {
        do {
            let output = try await client.delete_image_api_v1_discography_releases__release_id__editions__edition_id__images__image_id__delete(
                .init(path: .init(release_id: releaseID, edition_id: editionID, image_id: imageID))
            )
            switch output {
            case .noContent: return
            case .unauthorized: throw DiscographyError.forbidden
            case .forbidden: throw DiscographyError.forbidden
            case .notFound: throw DiscographyError.notFound
            case .unprocessableContent: throw DiscographyError.unexpected(422)
            case .undocumented(let c, _): throw DiscographyError.unexpected(c)
            }
        } catch let e as DiscographyError { throw e }
        catch { throw DiscographyError.network(error) }
    }

    // MARK: - Lectura

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
