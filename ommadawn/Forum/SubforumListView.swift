//
//  SubforumListView.swift
//  ommadawn
//
//  "Ver todo" de la actividad del foro (Inicio): lista los subforos y, al
//  entrar en uno, todos sus hilos (ForumThreadListView sin filtro de
//  entidad). Se presenta como hoja — necesita su propio NavigationStack.
//

import SwiftUI
import OmmadawnAPI

struct SubforumListView: View {
    let store: ForumStore

    @Environment(\.dismiss) private var dismiss
    @State private var subforums: [SubforumSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Subforos")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                }
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && subforums.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.slash")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Reintentar") { Task { await load() } }
            }
        } else if subforums.isEmpty {
            ContentUnavailableView(
                "Sin subforos todavía",
                systemImage: "square.stack",
                description: Text("Todavía no hay ninguna sección del foro creada.")
            )
        } else {
            List(subforums) { subforum in
                NavigationLink {
                    ForumThreadListView(
                        store: store,
                        subforumId: subforum.id,
                        navigationTitle: subforum.name,
                        showsCloseButton: false
                    )
                } label: {
                    SubforumRow(subforum: subforum)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            subforums = try await store.fetchSubforums()
        } catch {
            errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
        }
    }
}

private struct SubforumRow: View {
    let subforum: SubforumSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: subforum.icon ?? "bubble.left.and.bubble.right")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(subforum.name)
                    .font(.body)
                if let description = subforum.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
