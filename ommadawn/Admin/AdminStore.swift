//
//  AdminStore.swift
//  ommadawn
//
//  Gestión de usuarios reservada a superadministradores: listar y promover
//  o degradar a administrador. Mismo patrón que DiscographyStore: envuelve
//  el Client autenticado de AuthSession en vez de crear uno propio.
//

import Foundation
import OmmadawnAPI

/// Motivos por los que una llamada de administración puede fallar.
enum AdminError: Error {
    case forbidden     // 403 — el usuario autenticado no es superadministrador
    case notFound      // 404 — el usuario a promover/degradar no existe
    case unexpected(Int)
    case network(Error)
}

struct AdminStore {
    private let client: Client

    init(client: Client) {
        self.client = client
    }

    /// Lista todos los usuarios (para elegir a quién promover a admin).
    func listUsers() async throws -> [User] {
        do {
            let output = try await client.list_users_api_v1_auth_users_get(.init())
            switch output {
            case .ok(let ok):
                return try ok.body.json
            case .unauthorized:
                throw AdminError.forbidden
            case .forbidden:
                throw AdminError.forbidden
            case .undocumented(let statusCode, _):
                throw AdminError.unexpected(statusCode)
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.network(error)
        }
    }

    /// Promueve o degrada a un usuario como administrador.
    func setAdmin(userID: Int, isAdmin: Bool) async throws -> User {
        do {
            let output = try await client.update_user_admin_status_api_v1_auth_users__user_id__patch(
                .init(path: .init(user_id: userID), body: .json(.init(is_admin: isAdmin)))
            )
            switch output {
            case .ok(let ok):
                return try ok.body.json
            case .unauthorized, .forbidden:
                throw AdminError.forbidden
            case .notFound:
                throw AdminError.notFound
            case .unprocessableContent:
                throw AdminError.unexpected(422)
            case .undocumented(let statusCode, _):
                throw AdminError.unexpected(statusCode)
            }
        } catch let error as AdminError {
            throw error
        } catch {
            throw AdminError.network(error)
        }
    }
}
