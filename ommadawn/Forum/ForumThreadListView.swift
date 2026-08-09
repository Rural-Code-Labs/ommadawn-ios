//
//  ForumThreadListView.swift
//  ommadawn
//
//  Listado de hilos del foro para un disco, una edición, o el ámbito general
//  de discografía — también usada para ver TODOS los hilos de un subforo
//  (desde SubforumListView). Se presenta como hoja cuando `showsCloseButton`
//  es true (necesita su propio NavigationStack, ya que una .sheet no hereda
//  el de la vista que la abre) o empujada dentro de un stack ya existente.
//

import SwiftUI
import OmmadawnAPI

private let pageSize = 20

struct ForumThreadListView: View {
    let store: ForumStore
    /// Si se conoce de antemano (ej. al entrar desde `SubforumListView`), se
    /// usa directamente. Si no (ej. al abrir desde un disco/edición, que no
    /// sabe en qué subforo vive la discusión), se resuelve el primero — hoy
    /// sigue siendo "Discusiones".
    var subforumId: Int? = nil
    var entityType: ForumEntityType? = nil
    var entityId: Int? = nil
    let navigationTitle: String
    /// `false` cuando esta vista se empuja dentro de un `NavigationStack` ya
    /// existente (ej. desde `SubforumListView`) en vez de presentarse como
    /// hoja propia — ahí no hace falta un botón "Cerrar".
    var showsCloseButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var session

    @State private var threads: [ForumThreadSummary] = []
    @State private var total: Int = 0
    @State private var resolvedSubforum: SubforumSummary?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var showingCompose = false

    private var isAdmin: Bool {
        guard case .signedIn(let user) = session.state else { return false }
        return user.is_admin
    }

    /// El botón de crear se oculta si el subforo es `admin_only` y no eres
    /// admin — la API igualmente lo rechazaría, pero así no hace falta
    /// esperar a que lo haga.
    private var canCompose: Bool {
        guard let resolvedSubforum else { return false }
        return !resolvedSubforum.admin_only || isAdmin
    }

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                }
                if canCompose {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCompose = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showingCompose) {
                if let subforumId = resolvedSubforum?.id {
                    ForumThreadComposeView(
                        store: store,
                        subforumId: subforumId,
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
                        total += 1
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
            List {
                ForEach(threads) { thread in
                    NavigationLink(value: thread) {
                        ForumThreadRow(thread: thread)
                    }
                }
                if threads.count < total {
                    HStack {
                        Spacer()
                        if isLoadingMore {
                            ProgressView()
                        } else {
                            Button("Cargar más") { Task { await loadMore() } }
                        }
                        Spacer()
                    }
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
            // Si el llamador no indicó un subforo concreto, se resuelve el
            // primero una vez (hoy "Discusiones") y se usa tanto para filtrar
            // como para crear hilos nuevos (subforum_id es obligatorio al crear).
            if resolvedSubforum == nil {
                let subforums = try await store.fetchSubforums()
                resolvedSubforum = subforumId.flatMap { id in subforums.first { $0.id == id } } ?? subforums.first
            }
            let page = try await store.fetchThreads(
                subforumId: resolvedSubforum?.id,
                entityType: entityType,
                entityId: entityId,
                limit: pageSize,
                offset: 0
            )
            threads = page.items
            total = page.total
        } catch {
            errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
        }
    }

    private func loadMore() async {
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await store.fetchThreads(
                subforumId: resolvedSubforum?.id,
                entityType: entityType,
                entityId: entityId,
                limit: pageSize,
                offset: threads.count
            )
            threads.append(contentsOf: page.items)
            total = page.total
        } catch {
            // Sin mensaje aparte: el usuario puede reintentar tocando de nuevo "Cargar más".
        }
    }
}

/// `showsContext` añade una línea con el subforo y a qué se refiere el hilo
/// (disco/edición/discografía) — útil en listados agregados (Inicio) donde,
/// a diferencia de `ForumThreadListView` (ya filtrado a una entidad), no es
/// obvio de dónde viene cada hilo.
struct ForumThreadRow: View {
    let thread: ForumThreadSummary
    var showsContext = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.title)
                    .font(.body)
                if showsContext {
                    Text(contextLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private var contextLabel: String {
        guard let entityType = thread.entity_type else { return thread.subforum_name }
        return "\(thread.subforum_name) · \(entityType.displayName)"
    }
}
