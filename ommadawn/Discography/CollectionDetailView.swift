//
//  CollectionDetailView.swift
//  ommadawn
//
//  Detalle de una colección (Fase 6): sus ediciones, ordenadas por fecha de
//  publicación (nunca a mano — lo decide la API). A diferencia de
//  `EditionListSheet`, aquí cada fila puede pertenecer a un disco distinto,
//  así que cada una lleva su propio título de obra, no se puede dar por
//  hecho el contexto.
//
//  Tocar una fila pide el `Release` completo (esta vista solo tiene los
//  datos resumidos de `CollectionEditionRead`) y navega a su detalle — el
//  mismo patrón de "cargar antes de navegar" que ya usa la app en sitios
//  donde no se dispone del objeto completo de antemano.
//

import SwiftUI
import OmmadawnAPI

struct CollectionDetailView: View {
    let collectionID: Int
    let store: DiscographyStore

    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var collection: CollectionDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadingEditionID: Int?
    @State private var selectedRelease: Release?
    @State private var navigationError: String?
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    @State private var showingEdit = false

    private var isAdmin: Bool {
        guard case .signedIn(let user) = session.state else { return false }
        return user.is_admin
    }

    var body: some View {
        content
            .navigationTitle(collection?.name ?? "Colección")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .toolbar {
                if isAdmin, let collection {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Editar colección") {
                                showingEdit = true
                            }
                            Button("Eliminar colección", role: .destructive) {
                                showingDeleteConfirm = true
                            }
                            .disabled(!collection.editions.isEmpty)
                        } label: {
                            if isDeleting {
                                ProgressView()
                            } else {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        .disabled(isDeleting)
                    }
                }
            }
            .confirmationDialog(
                "¿Eliminar esta colección?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Eliminar", role: .destructive) { Task { await delete() } }
            } message: {
                Text("Esta acción no se puede deshacer.")
            }
            .navigationDestination(item: $selectedRelease) { release in
                ReleaseDetailView(release: release)
            }
            .sheet(isPresented: $showingEdit) {
                if let collection {
                    CollectionFormView(store: store, existing: collection, onUpdated: { updated in
                        self.collection = updated
                    })
                }
            }
            .alert("No se pudo abrir", isPresented: Binding(
                get: { navigationError != nil },
                set: { if !$0 { navigationError = nil } }
            )) {
                Button("Vale", role: .cancel) {}
            } message: {
                Text(navigationError ?? "")
            }
            .alert("Aviso", isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )) {
                Button("Vale", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && collection == nil {
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
        } else if let collection {
            List {
                if let description = collection.description, !description.isEmpty {
                    Section {
                        Text(description)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(collection.editions) { edition in
                        Button {
                            Task { await openRelease(for: edition) }
                        } label: {
                            CollectionEditionRow(edition: edition, isLoading: loadingEditionID == edition.id)
                        }
                        .disabled(loadingEditionID != nil)
                        .foregroundStyle(.primary)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            collection = try await store.fetchCollection(id: collectionID)
        } catch {
            errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
        }
    }

    private func delete() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            let deleted = try await store.deleteCollection(id: collectionID)
            if deleted {
                dismiss()
            } else {
                deleteErrorMessage = "La colección todavía tiene ediciones."
            }
        } catch {
            deleteErrorMessage = "No se pudo eliminar la colección. Inténtalo de nuevo."
        }
    }

    private func openRelease(for edition: CollectionEdition) async {
        loadingEditionID = edition.id
        defer { loadingEditionID = nil }
        do {
            selectedRelease = try await store.fetchRelease(id: edition.release_id)
        } catch {
            navigationError = "No se pudo abrir \"\(edition.release_title)\". Inténtalo de nuevo."
        }
    }
}

private struct CollectionEditionRow: View {
    let edition: CollectionEdition
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 48, height: 48)
                .overlay {
                    if let urlString = edition.cover_url, let url = URL(string: urlString) {
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
                Text(edition.release_title)
                    .font(.body)
                Text([edition.edition_name, edition.release_type.displayName].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoading {
                ProgressView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        CollectionDetailView(collectionID: 1, store: DiscographyStore(client: AuthSession(initialState: .signedOut).client))
    }
}
