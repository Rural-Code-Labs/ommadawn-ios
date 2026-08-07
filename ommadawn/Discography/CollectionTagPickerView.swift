//
//  CollectionTagPickerView.swift
//  ommadawn
//
//  Selección multi-tag de colecciones para una edición — mismo patrón que
//  LabelPickerView (buscar o crear), pero multi-selección: una edición
//  puede pertenecer a varias colecciones a la vez, a diferencia del sello.
//
//  Cada tap llama a la API de inmediato (añade o quita), no se difiere a un
//  "Guardar" — mismo criterio que las imágenes de una edición.
//

import SwiftUI
import OmmadawnAPI

struct CollectionTagPickerView: View {
    let editionID: Int
    @Binding var selected: [CollectionTag]
    let store: DiscographyStore

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var allCollections: [CollectionSummary] = []
    @State private var isLoading = false
    @State private var isCreating = false
    @State private var togglingID: Int?
    @State private var errorMessage: String?

    private var filtered: [CollectionSummary] {
        let sorted = allCollections.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedStandardContains(query) }
    }

    private func isSelected(_ id: Int) -> Bool {
        selected.contains { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            List {
                if !query.isEmpty && !filtered.contains(where: { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }) {
                    Section {
                        Button {
                            Task { await createAndAdd(name: query.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        } label: {
                            SwiftUI.Label("Crear «\(query.trimmingCharacters(in: .whitespacesAndNewlines))»", systemImage: "plus.circle")
                        }
                        .disabled(isCreating || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if filtered.isEmpty && !isLoading {
                    Section {
                        Text(query.isEmpty ? "No hay colecciones" : "Sin resultados")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(filtered) { collection in
                            Button {
                                Task { await toggle(collection) }
                            } label: {
                                HStack {
                                    Text(collection.name)
                                    Spacer()
                                    if togglingID == collection.id {
                                        ProgressView()
                                    } else if isSelected(collection.id) {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                            .disabled(togglingID != nil)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Colecciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar colección…")
            .task { await load() }
            .overlay {
                if isLoading && allCollections.isEmpty { ProgressView() }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            allCollections = try await store.fetchCollections()
        } catch {
            errorMessage = "Error al cargar colecciones"
        }
    }

    private func toggle(_ collection: CollectionSummary) async {
        togglingID = collection.id
        errorMessage = nil
        defer { togglingID = nil }
        do {
            if isSelected(collection.id) {
                try await store.removeEdition(editionID, fromCollection: collection.id)
                selected.removeAll { $0.id == collection.id }
            } else {
                _ = try await store.addEdition(editionID, toCollection: collection.id)
                selected.append(CollectionTag(id: collection.id, name: collection.name))
            }
        } catch DiscographyError.forbidden {
            errorMessage = "Sin permisos para esta acción"
        } catch {
            errorMessage = "Error al actualizar la colección"
        }
    }

    private func createAndAdd(name: String) async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            let created = try await store.createCollection(name: name)
            allCollections.append(CollectionSummary(id: created.id, name: created.name, edition_count: 1, sample_cover_urls: []))
            _ = try await store.addEdition(editionID, toCollection: created.id)
            selected.append(CollectionTag(id: created.id, name: created.name))
            query = ""
        } catch DiscographyError.unexpected(409) {
            await load()
            errorMessage = "Ya existe una colección con ese nombre"
        } catch {
            errorMessage = "Error al crear la colección"
        }
    }
}
