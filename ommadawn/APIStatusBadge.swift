//
//  APIStatusBadge.swift
//  ommadawn
//
//  Indicador de DESARROLLO: comprueba si la API responde llamando a
//  `GET /health` con el cliente generado en OmmadawnAPI. Es la primera
//  llamada real de la app a la API — sirve para cerrar la Fase 2.
//
//  Es temporal/diagnóstico: se puede quitar cuando ya no haga falta.
//

import SwiftUI
import OmmadawnAPI

struct APIStatusBadge: View {
    private enum Status {
        case checking, up, down
    }

    @State private var status: Status = .checking

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: .capsule)
        .task { await check() }
    }

    private var color: Color {
        switch status {
        case .checking: .yellow
        case .up: .green
        case .down: .red
        }
    }

    private var label: String {
        switch status {
        case .checking: "Comprobando API…"
        case .up: "API conectada"
        case .down: "API sin conexión"
        }
    }

    /// Llama a `GET /health`. Si responde 200, la API está viva.
    private func check() async {
        do {
            let client = Client(environment: .development)
            let response = try await client.health_health_get()
            // `.ok` lanza si la respuesta no fue 200; aquí solo nos importa
            // que la API respondió correctamente.
            _ = try response.ok
            status = .up
        } catch {
            status = .down
        }
    }
}

#Preview {
    APIStatusBadge()
}
