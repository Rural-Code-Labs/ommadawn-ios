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

struct ReleaseListView: View {
    @Environment(AuthSession.self) private var session

    @State private var releases: [Release] = []
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

    private var store: DiscographyStore { DiscographyStore(client: session.client) }

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
        content
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                floatingControls
            }
            .task(id: typeFilter) {
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && releases.isEmpty {
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
                ForEach(sortedReleases, id: \.id) { release in
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
        List(sortedReleases, id: \.id) { release in
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

    /// Filtro/orden y cambio de vista, flotantes sobre el contenido cerca
    /// del borde inferior derecho, uno encima del otro.
    private var floatingControls: some View {
        VStack(spacing: 14) {
            filterMenu
            viewModeButton
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
