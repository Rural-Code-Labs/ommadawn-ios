//
//  AppTheme.swift
//  ommadawn
//
//  Apariencia de la app. Por defecto sigue al sistema (automático). El botón
//  de la esquina alterna claro/oscuro: empieza mostrando el estado del sistema
//  y, al pulsar, cambia al contrario. La elección se guarda (@AppStorage) y se
//  aplica en la raíz con `.preferredColorScheme`.
//

import SwiftUI

enum AppTheme: String {
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
}

/// Botón que alterna claro/oscuro. El icono refleja el modo actual (sol/luna)
/// y su color es blanco/negro según la apariencia, nunca el azul de acento.
struct ThemeSwitcher: View {
    @Binding var theme: AppTheme
    @Environment(\.colorScheme) private var scheme

    private var isDark: Bool { scheme == .dark }

    var body: some View {
        Button {
            // Cambia a lo contrario de lo que se ve ahora.
            theme = isDark ? .light : .dark
        } label: {
            Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary) // negro en claro, blanco en oscuro
                .frame(width: 44, height: 44) // área de toque cómoda
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDark ? "Cambiar a claro" : "Cambiar a oscuro")
    }
}
