//
//  ContentView.swift
//  ommadawn
//
//  Created by Rafael García on 23/07/2026.
//

import SwiftUI

/// Vista raíz de la app. Hace de "router" de nivel superior.
///
/// Por ahora solo muestra el login. En la Fase 3, cuando exista estado de
/// autenticación, aquí se decidirá qué enseñar:
///   - sesión iniciada  → app principal (discografía, conciertos…)
///   - sin sesión        → LoginView
struct ContentView: View {
    var body: some View {
        LoginView()
            // Badge de diagnóstico (Fase 2): ¿responde la API? Temporal.
            .overlay(alignment: .bottom) {
                APIStatusBadge()
                    .padding(.bottom, 8)
            }
    }
}

#Preview {
    ContentView()
}
