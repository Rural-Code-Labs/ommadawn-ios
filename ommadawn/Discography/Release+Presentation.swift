//
//  Release+Presentation.swift
//  ommadawn
//
//  Helpers de presentación sobre los tipos generados del contrato. Viven en
//  el target de la app (no en OmmadawnAPI): son decisiones de cómo se
//  muestra el catálogo, no del contrato en sí.
//

import Foundation
import OmmadawnAPI

extension Release {
    /// La edición a mostrar por defecto: la marcada `is_primary` o, si el
    /// catálogo aún no tiene ninguna marcada, la primera que haya.
    var displayEdition: Edition? {
        editions.first(where: \.is_primary) ?? editions.first
    }

    /// Portada de `displayEdition`, si la tiene.
    var coverURL: URL? {
        guard let cover = displayEdition?.images.first(where: { $0.image_type == .front_cover }) else {
            return nil
        }
        return URL(string: cover.url)
    }
}

extension EditionFormat {
    var displayName: String {
        switch self {
        case .vinyl:      "Vinilo"
        case .cd:         "CD"
        case .single:     "Single"
        case .maxi_single:"Maxi Single"
        case .cd_single:  "CD Single"
        case .cassette:   "Casete"
        }
    }
}

extension ReleaseType {
    // Ya conforma a CaseIterable en el tipo generado (Types.swift); solo
    // añadimos aquí la presentación en español.

    /// Nombre en español para filtros y etiquetas.
    var displayName: String {
        switch self {
        case .studio: "Estudio"
        case .compilation: "Recopilatorio"
        case .single: "Single"
        case .bootleg: "Bootleg"
        }
    }
}
