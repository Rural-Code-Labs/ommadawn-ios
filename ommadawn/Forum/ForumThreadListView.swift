//
//  ForumThreadListView.swift
//  ommadawn
//
//  Listado de hilos del foro para un disco, una edición, o el ámbito general
//  de discografía. Se presenta como hoja (necesita su propio NavigationStack
//  porque una .sheet no hereda el de la vista que la abre).
//

import SwiftUI
import OmmadawnAPI

struct ForumThreadListView: View {
    let store: ForumStore
    let entityType: ForumEntityType?
    let entityId: Int?
    let navigationTitle: String

    @Environment(\.dismiss) private var dismiss

    @State private var threads: [ForumThreadSummary] = []
    @State private var subforum: SubforumSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCompose = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCompose = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .disabled(subforum == nil)
                    }
                }
                .task { await load() }
                .sheet(isPresented: $showingCompose) {
                    if let subforum {
                        ForumThreadComposeView(
                            store: store,
                            subforumId: subforum.id,
                            entityType: entityType,
                            entityId: entityId
                        ) { created in
                            threads.insert(
                                ForumThreadSummary(
                                    id: created.id,
                                    title: created.title,
                                    author_id: created.author_id,
                                    author_username: created.author_username,
                                    subforum_id: created.subforum_id,
                                    subforum_name: created.subforum_name,
                                    entity_type: created.entity_type,
                                    entity_id: created.entity_id,
                                    status: created.status,
                                    comment_count: created.comments.count,
                                    created_at: created.created_at,
                                    updated_at: created.updated_at
                                ),
                                at: 0
                            )
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && threads.isEmpty {
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
        } else if threads.isEmpty {
            ContentUnavailableView(
                "Sin hilos todavía",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Sé el primero en abrir un hilo aquí.")
            )
        } else {
            List(threads) { thread in
                NavigationLink(value: thread) {
                    ForumThreadRow(thread: thread)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
            .navigationDestination(for: ForumThreadSummary.self) { thread in
                ForumThreadDetailView(threadID: thread.id, store: store)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // Hoy solo existe un subforo ("Discusiones"): se resuelve una
            // vez y se usa tanto para filtrar como para crear hilos nuevos
            // (subforum_id es obligatorio al crear).
            if subforum == nil {
                subforum = try await store.fetchSubforums().first
            }
            threads = try await store.fetchThreads(subforumId: subforum?.id, entityType: entityType, entityId: entityId)
        } catch {
            errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
        }
    }
}

private struct ForumThreadRow: View {
    let thread: ForumThreadSummary

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.title)
                    .font(.body)
                Text("\(thread.author_username) · \(thread.created_at.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(thread.status.displayName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(thread.status.tintColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(thread.status.tintColor)
                if thread.comment_count > 0 {
                    Label("\(thread.comment_count)", systemImage: "bubble.left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
