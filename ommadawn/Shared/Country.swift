//
//  Country.swift
//  ommadawn
//
//  Modelo de país con código ISO 3166-1 alpha-2, nombre en español (vía
//  Locale) y bandera emoji. La lista completa se genera a partir de
//  Locale.isoRegionCodes sin hardcodear nada.
//

import Foundation

struct Country: Identifiable, Hashable {
    let code: String   // ISO 3166-1 alpha-2, ej. "GB"
    let name: String   // Nombre en español, ej. "Reino Unido"

    var id: String { code }
    var flag: String { code.flagEmoji }
    var displayName: String { "\(flag) \(name)" }
}

extension Country {
    // Códigos supranacionales que la API acepta aunque no sean ISO 3166-1 alpha-2
    // estrictos. Se amplía aquí cuando la API añada soporte para más.
    private static let extraCodes = ["EU"]

    // NSLocale.isoCountryCodes da solo países soberanos; los extraCodes se
    // añaden manualmente y la lista final se reordena alfabéticamente.
    static let all: [Country] = {
        let locale = Locale(identifier: "es")
        let codes = NSLocale.isoCountryCodes + extraCodes
        return codes
            .compactMap { code -> Country? in
                guard let name = locale.localizedString(forRegionCode: code) else { return nil }
                return Country(code: code, name: name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }()

    static func find(_ code: String?) -> Country? {
        guard let code else { return nil }
        return all.first { $0.code == code.uppercased() }
    }
}

extension String {
    /// Convierte un código ISO 3166-1 alpha-2 en su bandera emoji. "GB" → 🇬🇧
    var flagEmoji: String {
        uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
    }
}
