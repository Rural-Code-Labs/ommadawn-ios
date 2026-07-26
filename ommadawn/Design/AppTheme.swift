//
//  AppTheme.swift
//  ommadawn
//
//  Apariencia de la app. Por defecto sigue al sistema (automático). La
//  elección se guarda (@AppStorage, clave "appearance") y se aplica en la
//  raíz (ContentView) con `.preferredColorScheme`; el control para cambiarla
//  vive en Cuenta (AppearancePicker), no flotando por toda la app.
//

import SwiftUI

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
