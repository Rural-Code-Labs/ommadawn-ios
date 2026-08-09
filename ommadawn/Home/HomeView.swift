//
//  HomeView.swift
//  ommadawn
//
//  Pestaña Inicio (Fase 7.5). Tres bloques, cada uno con su propia pantalla
//  "ver todo":
//  - Novedades: últimos 2 hilos del subforo "Novedades" (solo admins pueden
//    abrir hilos ahí — pendiente de sembrar ese subforo en la API, ver
//    CLAUDE.md). "Ver todas" abre ForumThreadListView filtrado a ese subforo.
//  - Actividad reciente del foro: últimos 5 hilos de cualquier subforo/
//    entidad. "Ver todo" abre SubforumListView (explorar por subforo).
//  - Changelog: contenido de ejemplo (sin backend todavía — pendiente de un
//    `updated_at` en Release/Edition). "Ver todo" abre ChangelogListView.
//

import SwiftUI
import OmmadawnAPI

struct HomeView: View {
    @Environment(AuthSession.self) private var session

    @State private var novedadesSubforumId: Int?
    @State private var novedadesThreads: [ForumThreadSummary] = []
    @State private var recentThreads: [ForumThreadSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingNovedades = false
    @State private var showingSubforums = false
    @State private var showingChangelog = false

    private var forumStore: ForumStore { ForumStore(client: session.client) }

    var body: some View {
        List {
            Section {
                if novedadesThreads.isEmpty {
                    Text(novedadesSubforumId == nil ? "Todavía no hay subforo de novedades." : "Sin novedades todavía.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(novedadesThreads) { thread in
                        NavigationLink(value: thread) {
                            ForumThreadRow(thread: thread)
                        }
                    }
                }
                Button("Ver todas las novedades") { showingNovedades = true }
                    .disabled(novedadesSubforumId == nil)
            } header: {
                Text("Novedades")
            }

            Section {
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
                Button("Ver todos los subforos") { showingSubforums = true }
            } header: {
                Text("Actividad reciente del foro")
            }

            Section {
                ForEach(sampleChangelog.prefix(3)) { entry in
                    changelogRow(entry)
                }
                Button("Ver todo el changelog") { showingChangelog = true }
            } header: {
                Text("Changelog")
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
        .task { await load() }
        .navigationDestination(for: ForumThreadSummary.self) { thread in
            ForumThreadDetailView(threadID: thread.id, store: forumStore)
        }
        .sheet(isPresented: $showingNovedades) {
            if let novedadesSubforumId {
                NavigationStack {
                    ForumThreadListView(
                        store: forumStore,
                        subforumId: novedadesSubforumId,
                        navigationTitle: "Novedades"
                    )
                }
            }
        }
        .sheet(isPresented: $showingSubforums) {
            SubforumListView(store: forumStore)
        }
        .sheet(isPresented: $showingChangelog) {
            ChangelogListView()
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

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let subforums = try await forumStore.fetchSubforums()
            // limit alto para poder ordenar por `updated_at` en el cliente
            // (la API ya devuelve "más recientes primero", pero por
            // creación, no por última actividad) — de sobra mientras el
            // foro tenga pocos hilos; si crece, esto necesitará un
            // parámetro de orden en la API en vez de traer de más.
            let recentPage = try await forumStore.fetchThreads(limit: 100)
            recentThreads = Array(recentPage.items.sorted { $0.updated_at > $1.updated_at }.prefix(5))

            if let novedades = subforums.first(where: { $0.name == "Novedades" }) {
                novedadesSubforumId = novedades.id
                let novedadesPage = try await forumStore.fetchThreads(subforumId: novedades.id, limit: 2)
                novedadesThreads = novedadesPage.items
            } else {
                novedadesSubforumId = nil
                novedadesThreads = []
            }
        } catch {
            errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
        }
    }
}
