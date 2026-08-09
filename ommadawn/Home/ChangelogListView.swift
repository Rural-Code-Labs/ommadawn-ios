//
//  ChangelogListView.swift
//  ommadawn
//
//  "Ver todo" del changelog en Inicio. Contenido de ejemplo, paginado
//  localmente (sin backend todavía — ver ChangelogEntry.swift).
//

import SwiftUI

struct ChangelogListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var visibleCount = 3

    private let entries = sampleChangelog

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries.prefix(visibleCount)) { entry in
                    changelogRow(entry)
                }
                if visibleCount < entries.count {
                    Button("Cargar más") {
                        visibleCount = min(visibleCount + 3, entries.count)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Changelog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func changelogRow(_ entry: ChangelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.body.weight(.semibold))
            Text(entry.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
