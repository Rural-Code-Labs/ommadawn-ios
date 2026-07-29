//
//  AppTheme.swift
//  ommadawn
//
//  Apariencia de la app. Por defecto sigue al sistema (automático). La
//  elección se guarda (@AppStorage, clave "appearance") y se aplica en la
//  raíz (ContentView) con `.preferredColorScheme`. El selector completo de
//  las tres opciones (AppearancePicker) vive en Cuenta; en el login hay
//  además un botón de un toque que recorre el ciclo (ver `next`/`iconName`).
//

import SwiftUI
import OmmadawnAPI

enum AppTheme: String, CaseIterable {
    case system   // sin preferencia → sigue al sistema
    case light
    case dark

    /// `nil` = automático (el sistema decide).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Oscuro"
        }
    }

    /// Siguiente valor del ciclo Sistema → Claro → Oscuro → Sistema, para
    /// el botón de cambio rápido de apariencia.
    var next: AppTheme {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }

    /// Icono representativo, para el botón de cambio rápido.
    var iconName: String {
        switch self {
        case .system: "circle.righthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

extension AppTheme {
    /// Valor equivalente en el contrato de la API.
    var apiValue: Components.Schemas.ThemePreference {
        switch self {
        case .system: .system
        case .light:  .light
        case .dark:   .dark
        }
    }

    /// Construye un `AppTheme` desde la preferencia almacenada en el servidor.
    init(from api: Components.Schemas.ThemePreference) {
        switch api {
        case .system: self = .system
        case .light:  self = .light
        case .dark:   self = .dark
        }
    }
}

/// Selector de apariencia (Sistema/Claro/Oscuro) para la pantalla de Cuenta.
struct AppearancePicker: View {
    @Binding var theme: AppTheme

    var body: some View {
        Picker("Apariencia", selection: $theme) {
            ForEach(AppTheme.allCases, id: \.self) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}
