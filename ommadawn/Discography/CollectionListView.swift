//
//  CollectionListView.swift
//  ommadawn
//
//  Listado de colecciones (Fase 6): ediciones de discos distintos agrupadas
//  bajo un nombre común, ej. "Remasterizaciones HDCD". Vive dentro de la
//  pestaña Discografía, activado por el segmented control de
//  `ReleaseListView` — no es una pantalla aparte, así que no lleva su propia
//  cabecera ni controles flotantes (los pone `ReleaseListView`).
//
//  Sin filtro de tipo ni grid/lista todavía: con el catálogo de colecciones
//  que hay hoy, una sola lista alfabética basta — esa complejidad se añade
//  el día que haga falta, no antes.
//

import SwiftUI
import OmmadawnAPI

struct CollectionListView: View {
    let store: DiscographyStore
    let searchText: String
    /// Propiedad de `ReleaseListView`, no de esta vista: así el botón "+"
    /// (que vive en `ReleaseListView`, junto al resto de controles
    /// flotantes) puede añadir la colección recién creada sin esperar a un
    /// pull-to-refresh — mismo patrón que ya usa `releases` con
    /// `ReleaseEditView`.
    @Binding var collections: [CollectionSummary]

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadTask: Task<Void, Never>?

    private var filtered: [CollectionSummary] {
        let sorted = collections.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        content
            .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && collections.isEmpty {
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
        } else if collections.isEmpty {
            ContentUnavailableView(
                "Sin colecciones todavía",
                systemImage: "rectangle.stack",
                description: Text("Las colecciones agrupan ediciones de discos distintos bajo un nombre común.")
            )
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List(filtered) { collection in
                NavigationLink(value: collection) {
                    CollectionRow(collection: collection)
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
            .navigationDestination(for: CollectionSummary.self) { collection in
                CollectionDetailView(collectionID: collection.id, store: store)
            }
        }
    }

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
                collections = try await store.fetchCollections()
            } catch {
                errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
            }
        }
        loadTask = task
        await task.value
        loadTask = nil
    }
}

private struct CollectionRow: View {
    let collection: CollectionSummary

    var body: some View {
        HStack(spacing: 12) {
            ChainedCovers(urls: collection.sample_cover_urls)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.body)
                Text("\(collection.edition_count) \(collection.edition_count == 1 ? "edición" : "ediciones")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Dos portadas encadenadas (o una, o el icono genérico si no hay ninguna) —
/// se usa tanto en el listado de colecciones como podría reutilizarse en
/// cualquier otro sitio que necesite representar "varias obras a la vez".
struct ChainedCovers: View {
    let urls: [String]

    var body: some View {
        GeometryReader { geo in
            let shown = Array(urls.prefix(3))
            // Con 3 portadas hace falta encogerlas más para que quepan
            // encadenadas sin salirse del marco disponible.
            let size = min(geo.size.width, geo.size.height) * (shown.count >= 3 ? 0.62 : 0.82)
            let step = shown.count > 1 ? (geo.size.width - size) / CGFloat(shown.count - 1) : 0
            ZStack(alignment: .topLeading) {
                if shown.isEmpty {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .frame(width: size, height: size)
                        .overlay {
                            Image(systemName: "opticaldisc").foregroundStyle(.secondary)
                        }
                } else {
                    ForEach(Array(shown.enumerated()), id: \.offset) { index, urlString in
                        cover(urlString)
                            .frame(width: size, height: size)
                            .offset(x: CGFloat(index) * step, y: CGFloat(index) * step)
                    }
                }
            }
        }
    }

    private func cover(_ urlString: String) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .overlay {
                AsyncImage(url: URL(string: urlString)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "opticaldisc").foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6).stroke(.background, lineWidth: 2)
            }
    }
}

/// Hoja de nombre + descripción, para crear una colección o editar una ya
/// existente (`existing` la distingue). Las ediciones no se tocan aquí: se
/// añaden por separado, desde `EditionEditView`.
struct CollectionFormView: View {
    let store: DiscographyStore
    var existing: CollectionDetail? = nil
    var onCreated: ((CollectionDetail) -> Void)? = nil
    var onUpdated: ((CollectionDetail) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        store: DiscographyStore,
        existing: CollectionDetail? = nil,
        onCreated: ((CollectionDetail) -> Void)? = nil,
        onUpdated: ((CollectionDetail) -> Void)? = nil
    ) {
        self.store = store
        self.existing = existing
        self.onCreated = onCreated
        self.onUpdated = onUpdated
        _name = State(initialValue: existing?.name ?? "")
        _description = State(initialValue: existing?.description ?? "")
    }

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)
                    TextField("Descripción (opcional)", text: $description, axis: .vertical)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar colección" : "Nueva colección")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Guardar" : "Crear") { Task { await save() } }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .disabled(isSaving)
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let existing {
                let updated = try await store.updateCollection(
                    id: existing.id,
                    name: trimmedName,
                    description: trimmedDescription
                )
                onUpdated?(updated)
            } else {
                let created = try await store.createCollection(
                    name: trimmedName,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription
                )
                onCreated?(created)
            }
            dismiss()
        } catch DiscographyError.unexpected(409) {
            errorMessage = "Ya existe una colección con ese nombre."
        } catch {
            errorMessage = isEditing ? "No se pudo guardar. Inténtalo de nuevo." : "No se pudo crear la colección. Inténtalo de nuevo."
        }
    }
}

#Preview {
    NavigationStack {
        CollectionListView(store: DiscographyStore(client: AuthSession(initialState: .signedOut).client), searchText: "", collections: .constant([]))
    }
}
