//
//  Forum+Presentation.swift
//  ommadawn
//
//  Helpers de presentación sobre los tipos generados del foro — mismo
//  criterio que Release+Presentation.swift: decisiones de cómo se muestra,
//  no del contrato en sí.
//

import SwiftUI
import OmmadawnAPI

extension ForumThreadStatus {
    var displayName: String {
        switch self {
        case .open: return "Abierto"
        case .resolved: return "Resuelto"
        case .closed: return "Cerrado"
        }
    }

    var tintColor: Color {
        switch self {
        case .open: return .blue
        case .resolved: return .green
        case .closed: return .secondary
        }
    }
}

extension ForumEntityType {
    var displayName: String {
        switch self {
        case .release: return "Disco"
        case .edition: return "Edición"
        case .discography: return "Discografía"
        }
    }
}
