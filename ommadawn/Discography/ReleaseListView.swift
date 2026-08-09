//
//  ReleaseListView.swift
//  ommadawn
//
//  Listado del catálogo (discografía). Filtro por tipo, orden (con dirección
//  asc/desc) y cambio de vista (grid ↔ lista) como controles flotantes cerca
//  del borde inferior derecho, uno encima del otro. Sin título propio: la
//  pestaña activa (RootTabView) ya dice en qué sección estamos, y la cabecera
//  común de la app vive por encima del TabView. El hueco para una futura
//  vista "temporal" (cronológica) queda listo en DisplayMode sin
//  implementarla aún.
//

import SwiftUI
import OmmadawnAPI

/// Cómo se presenta el listado. `.temporal` queda reservado para una futura
/// vista cronológica; hoy el selector solo alterna entre grid y lista.
enum DiscographyDisplayMode {
    case grid
    case list
}

/// Orden del listado. Por año usa la fecha de la edición principal (no hay
/// fecha en la obra en sí); las obras sin ninguna fecha conocida van al final.
enum ReleaseSortOrder {
    case year
    case name
}

/// Qué se está explorando dentro de la pestaña Discografía: discos (por
/// obra) o colecciones (ediciones de discos distintos agrupadas por nombre,
/// ej. "Remasterizaciones HDCD"). Un segmented control en la propia pestaña,
/// no una pantalla aparte — las colecciones son una forma más de navegar el
/// catálogo, no un extra escondido.
enum DiscographyScope {
    case releases
    case collections
}

struct ReleaseListView: View {
    @Environment(AuthSession.self) private var session

    @State private var scope: DiscographyScope = .releases
    @State private var releases: [Release] = []
    @State private var collections: [CollectionSummary] = []
    @State private var displayMode: DiscographyDisplayMode = .grid
    @State private var typeFilter: ReleaseType?
    @State private var sortOrder: ReleaseSortOrder = .year
    @State private var sortAscending = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// La carga en curso, si la hay. `.task` (al aparecer) y `.refreshable`
    /// (al deslizar) pueden llamar a `load()` casi a la vez; sin esto, la
    /// segunda cancelaba la petición HTTP de la primera (NSURLErrorCancelled).
    /// Compartir la misma tarea evita la carrera y ambos llamadores esperan
    /// el mismo resultado.
    @State private var loadTask: Task<Void, Never>?
    @State private var showingCreate = false
    @State private var showingCreateCollection = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingGeneralForum = false

    private var store: DiscographyStore { DiscographyStore(client: session.client) }
    private var forumStore: ForumStore { ForumStore(client: session.client) }

    private var isAdmin: Bool {
        guard case .signedIn(let user) = session.state else { return false }
        return user.is_admin
    }

    private var filteredReleases: [Release] {
        guard !searchText.isEmpty else { return sortedReleases }
        return sortedReleases.filter { $0.title.localizedStandardContains(searchText) }
    }

    private var sortedReleases: [Release] {
        let ascending = sortAscending
        switch sortOrder {
        case .year:
            return releases.sorted { lhs, rhs in
                let lyear = lhs.displayEdition?.release_date.flatMap { Int($0.prefix(4)) } ?? .max
                let ryear = rhs.displayEdition?.release_date.flatMap { Int($0.prefix(4)) } ?? .max
                if lyear != ryear { return ascending ? lyear < ryear : lyear > ryear }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .name:
            return releases.sorted {
                let order = $0.title.localizedStandardCompare($1.title)
                return ascending ? order == .orderedAscending : order == .orderedDescending
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            scopePicker
            if isSearching {
                searchBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            content
        }
        .animation(.snappy, value: isSearching)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomLeading) {
            leftFloatingControls
        }
        .overlay(alignment: .bottomTrailing) {
            rightFloatingControls
        }
            .task(id: typeFilter) {
                await load()
            }
            .sheet(isPresented: $showingCreate) {
                ReleaseEditView { newRelease in
                    releases.append(newRelease)
                }
            }
            .sheet(isPresented: $showingCreateCollection) {
                CollectionFormView(store: store, onCreated: { created in
                    collections.append(CollectionSummary(
                        id: created.id, name: created.name,
                        edition_count: created.editions.count,
                        sample_cover_urls: []
                    ))
                })
            }
            .sheet(isPresented: $showingGeneralForum) {
                NavigationStack {
                    ForumThreadListView(
                        store: forumStore,
                        entityType: .discography,
                        entityId: nil,
                        navigationTitle: "Discusión general"
                    )
                }
            }
    }

    /// "Discos | Colecciones" — cambia qué se explora en la pestaña, no
    /// navega a una pantalla aparte.
    private var scopePicker: some View {
        Picker("Ver", selection: $scope.animation(.snappy)) {
            Text("Discos").tag(DiscographyScope.releases)
            Text("Colecciones").tag(DiscographyScope.collections)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var content: some View {
        if scope == .collections {
            CollectionListView(store: store, searchText: searchText, collections: $collections)
        } else if isLoading && releases.isEmpty {
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
        } else if releases.isEmpty {
            ContentUnavailableView(
                "Sin obras todavía",
                systemImage: "opticaldisc",
                description: Text(typeFilter == nil ? "El catálogo está vacío." : "No hay obras de tipo \(typeFilter!.displayName.lowercased()).")
            )
        } else if filteredReleases.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            switch displayMode {
            case .grid: releaseGrid
            case .list: releaseList
            }
        }
    }

    private var releaseGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
                ForEach(filteredReleases, id: \.id) { release in
                    NavigationLink(value: release) {
                        ReleaseGridCell(release: release)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .refreshable { await load() }
        .navigationDestination(for: Release.self) { release in
            ReleaseDetailView(release: release)
        }
    }

    private var releaseList: some View {
        List(filteredReleases, id: \.id) { release in
            NavigationLink(value: release) {
                ReleaseListRow(release: release)
            }
        }
        .listStyle(.plain)
        .refreshable { await load() }
        .navigationDestination(for: Release.self) { release in
            ReleaseDetailView(release: release)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar por título", text: $searchText)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// Cápsula flotante inferior izquierda: crear (admin) y discusión
    /// general de discografía. Separada de los controles de la derecha
    /// porque no son de la misma familia (esos filtran/ordenan el propio
    /// listado; estos abren algo aparte).
    private var leftFloatingControls: some View {
        VStack(spacing: 14) {
            if isAdmin {
                Button {
                    if scope == .releases {
                        showingCreate = true
                    } else {
                        showingCreateCollection = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel(scope == .releases ? "Nuevo disco" : "Nueva colección")
            }
            Button {
                showingGeneralForum = true
            } label: {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel("Discusión general de discografía")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: Capsule())
        .padding(.leading, 12)
        .padding(.bottom, 20)
    }

    /// Filtro/orden y cambio de vista, flotantes sobre el contenido cerca
    /// del borde inferior derecho, uno encima del otro. En colecciones no
    /// hay filtro de tipo ni grid/lista: es una sola lista, no hace falta
    /// esa complejidad todavía.
    private var rightFloatingControls: some View {
        VStack(spacing: 14) {
            Button {
                if isSearching {
                    isSearching = false
                    searchText = ""
                } else {
                    isSearching = true
                }
            } label: {
                Image(systemName: isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel(isSearching ? "Cerrar búsqueda" : "Buscar")
            if scope == .releases {
                filterMenu
                viewModeButton
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: Capsule())
        .padding(.trailing, 12)
        .padding(.bottom, 20)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Ordenar por", selection: $sortOrder) {
                Text("Año").tag(ReleaseSortOrder.year)
                Text("Nombre").tag(ReleaseSortOrder.name)
            }
            Picker("Dirección", selection: $sortAscending) {
                Label("Ascendente", systemImage: "arrow.up").tag(true)
                Label("Descendente", systemImage: "arrow.down").tag(false)
            }
            Section("Tipo") {
                Picker("Tipo", selection: $typeFilter) {
                    Text("Todos").tag(ReleaseType?.none)
                    ForEach(ReleaseType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(ReleaseType?.some(type))
                    }
                }
            }
        } label: {
            Image(systemName: typeFilter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 18))
                .frame(width: 24, height: 24)
        }
        .accessibilityLabel("Filtrar y ordenar")
    }

    private var viewModeButton: some View {
        Button {
            displayMode = displayMode == .grid ? .list : .grid
        } label: {
            Image(systemName: displayMode == .grid ? "list.bullet" : "square.grid.2x2")
                .font(.system(size: 18))
                .frame(width: 24, height: 24)
        }
        .accessibilityLabel(displayMode == .grid ? "Ver como lista" : "Ver como cuadrícula")
    }

    /// Si ya hay una carga en curso, se une a ella en vez de lanzar otra
    /// (ver el comentario de `loadTask`).
    private func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                releases = try await store.fetchReleases(type: typeFilter)
            } catch {
                errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
            }
        }
        loadTask = task
        await task.value
        loadTask = nil
    }
}

private struct ReleaseGridCell: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let url = release.coverURL {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "opticaldisc")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "opticaldisc")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(release.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            Text(release.release_type.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ReleaseListRow: View {
    let release: Release

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 48, height: 48)
                .overlay {
                    if let url = release.coverURL {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "opticaldisc").foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "opticaldisc").foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(release.title)
                    .font(.body)
                Text(release.release_type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReleaseListView()
    }
    .environment(AuthSession(initialState: .signedOut))
}
