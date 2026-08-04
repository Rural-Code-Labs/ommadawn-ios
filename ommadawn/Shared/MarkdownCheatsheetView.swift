//
//  MarkdownCheatsheetView.swift
//  ommadawn
//
//  Referencia rápida de la sintaxis Markdown más común.
//

import SwiftUI

struct MarkdownCheatsheetView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Item: Identifiable {
        let id = UUID()
        let name: String
        let syntax: String
        let result: String
    }

    private let items: [Item] = [
        Item(name: "Negrita",    syntax: "**texto**",       result: "texto en negrita"),
        Item(name: "Cursiva",    syntax: "_texto_",         result: "texto en cursiva"),
        Item(name: "Enlace",     syntax: "[texto](url)",    result: "texto con enlace"),
        Item(name: "Título 1",   syntax: "# Título",        result: "encabezado grande"),
        Item(name: "Título 2",   syntax: "## Título",       result: "encabezado mediano"),
        Item(name: "Título 3",   syntax: "### Título",      result: "encabezado pequeño"),
        Item(name: "Lista",      syntax: "- elemento",      result: "elemento de lista"),
        Item(name: "Lista num.", syntax: "1. elemento",     result: "lista numerada"),
        Item(name: "Cita",       syntax: "> texto",         result: "bloque de cita"),
        Item(name: "Código",     syntax: "`código`",        result: "código en línea"),
        Item(name: "Separador",  syntax: "---",             result: "línea horizontal"),
    ]

    var body: some View {
        NavigationStack {
            List(items) { item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.body)
                        Text(item.result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.syntax)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Sintaxis Markdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MarkdownCheatsheetView()
}
