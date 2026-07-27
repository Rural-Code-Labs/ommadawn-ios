//
//  User+Presentation.swift
//  ommadawn
//
//  Helpers de presentación sobre `User` (alias de `UserRead`) — cómo se
//  muestra el usuario, no parte del contrato en sí. Mismo patrón que
//  Release+Presentation.swift en Discography.
//

import Foundation
import OmmadawnAPI

extension User {
    /// Nombre a mostrar: el `full_name` si lo hay, si no el `username`.
    var displayName: String {
        if let name = full_name, !name.isEmpty { return name }
        return username
    }

    var avatarURL: URL? {
        guard let avatar_url else { return nil }
        return URL(string: avatar_url)
    }
}
