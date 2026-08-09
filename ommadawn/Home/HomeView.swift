//
//  HomeView.swift
//  ommadawn
//
//  Pestaña Inicio (Fase 7.5). Tres bloques pensados para ir creciendo:
//  noticias (hoy con contenido de ejemplo — no hay backend de noticias
//  todavía), actividad reciente del foro (últimos hilos con creación,
//  comentario o cambio de estado) y, en el futuro, un changelog del catálogo
//  (pendiente de un campo `updated_at` en Release/Edition que la API no
//  tiene aún — ver CLAUDE.md).
//

import SwiftUI
import OmmadawnAPI

/// Contenido de ejemplo: no hay backend de noticias todavía. Se sustituye
/// por datos reales el día que exista esa sección en la API.
private struct DummyNews: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let summary: String
}

private let sampleNews: [DummyNews] = [
    DummyNews(
        title: "Bienvenido al foro de Ommadawn",
        date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
        summary: "Ya puedes proponer cambios y discutirlos en cualquier disco, edición o de forma general."
    ),
    DummyNews(
        title: "Colecciones de ediciones",
        date: Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now,
        summary: "Agrupa ediciones de discos distintos bajo un nombre común, como \"Remasterizaciones HDCD\"."
    ),
    DummyNews(
        title: "Login con Google",
        date: Calendar.current.date(byAdding: .day, value: -9, to: .now) ?? .now,
        summary: "Ahora puedes entrar y vincular tu cuenta de Google desde el perfil."
    ),
]

struct HomeView: View {
    @Environment(AuthSession.self) private var session

    @State private var recentThreads: [ForumThreadSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var forumStore: ForumStore { ForumStore(client: session.client) }

    var body: some View {
        List {
            Section("Novedades") {
                ForEach(sampleNews) { news in
                    newsRow(news)
                }
            }

            Section("Actividad reciente del foro") {
                if isLoading && recentThreads.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else if recentThreads.isEmpty {
                    Text("Todavía no hay actividad en el foro.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentThreads) { thread in
                        NavigationLink(value: thread) {
                            ForumThreadRow(thread: thread, showsContext: true)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
        .task { await load() }
        .navigationDestination(for: ForumThreadSummary.self) { thread in
            ForumThreadDetailView(threadID: thread.id, store: forumStore)
        }
    }

    private func newsRow(_ news: DummyNews) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(news.title)
                .font(.body.weight(.semibold))
            Text(news.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(news.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let threads = try await forumStore.fetchThreads()
            recentThreads = Array(threads.sorted { $0.updated_at > $1.updated_at }.prefix(5))
        } catch {
            errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
        }
    }
}
