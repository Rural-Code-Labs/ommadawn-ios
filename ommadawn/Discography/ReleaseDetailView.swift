//
//  ReleaseDetailView.swift
//  ommadawn
//
//  Detalle de una obra: portada, selector de edición (si hay más de una),
//  tracklist de la edición activa e imágenes. Recibe el Release ya completo
//  desde el listado (el contrato ya anida ediciones/temas/imágenes); el
//  pull-to-refresh es lo único que vuelve a pedirlo a la API.
//

import SwiftUI
import OmmadawnAPI

struct ReleaseDetailView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var release: Release
    @State private var selectedEditionID: Int?

    // Estado del menú de Release
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false

    // Estado del menú de Edition
    @State private var showingCreateEdition = false
    @State private var showingEditEdition = false
    @State private var showingDeleteEditionConfirm = false
    @State private var isDeletingEdition = false
    @State private var showingEditionImages = false

    init(release: Release) {
        _release = State(initialValue: release)
        _selectedEditionID = State(initialValue: release.displayEdition?.id)
    }

    private var store: DiscographyStore { DiscographyStore(client: session.client) }

    private var isAdmin: Bool {
        guard case .signedIn(let user) = session.state else { return false }
        return user.is_admin
    }

    private var selectedEdition: Edition? {
        release.editions.first { $0.id == selectedEditionID } ?? release.displayEdition
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if release.editions.isEmpty {
                    ContentUnavailableView(
                        "Sin ediciones todavía",
                        systemImage: "circle.dashed",
                        description: Text("Esta obra aún no tiene ninguna edición publicada.")
                    )
                    .padding(.top, 40)
                } else {
                    if release.editions.count > 1 {
                        editionList
                    }
                    if let edition = selectedEdition {
                        editionMeta(edition)
                        if !edition.tracks.isEmpty {
                            tracklist(edition.tracks)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(release.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refresh() }
        .toolbar {
            if isAdmin {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Acciones del disco
                        Button { showingEdit = true } label: {
                            Label("Editar disco", systemImage: "pencil")
                        }
                        Button(role: .destructive) { showingDeleteConfirm = true } label: {
                            Label("Eliminar disco", systemImage: "trash")
                        }

                        Divider()

                        // Acciones de la edición seleccionada
                        Button { showingCreateEdition = true } label: {
                            Label("Nueva edición", systemImage: "plus.circle")
                        }
                        if selectedEdition != nil {
                            Button { showingEditEdition = true } label: {
                                Label("Editar edición", systemImage: "pencil.circle")
                            }
                            Button { showingEditionImages = true } label: {
                                Label("Imágenes de la edición", systemImage: "photo.stack")
                            }
                            Button(role: .destructive) { showingDeleteEditionConfirm = true } label: {
                                Label("Eliminar edición", systemImage: "minus.circle")
                            }
                        }
                    } label: {
                        if isDeleting || isDeletingEdition {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        // Sheets de Release
        .sheet(isPresented: $showingEdit) {
            ReleaseEditView(release: release) { updated in
                release = updated
            }
        }
        .confirmationDialog(
            "¿Eliminar \"\(release.title)\"?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { Task { await deleteRelease() } }
        } message: {
            Text("Se eliminarán también todas sus ediciones y temas. Esta acción no se puede deshacer.")
        }
        // Sheets de Edition
        .sheet(isPresented: $showingCreateEdition) {
            EditionEditView(release: release) { newEdition in
                release.editions.append(newEdition)
                selectedEditionID = newEdition.id
            }
        }
        .sheet(isPresented: $showingEditEdition) {
            if let edition = selectedEdition {
                EditionEditView(release: release, edition: edition) { updated in
                    if let idx = release.editions.firstIndex(where: { $0.id == updated.id }) {
                        release.editions[idx] = updated
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditionImages, onDismiss: { Task { await refresh() } }) {
            if let edition = selectedEdition {
                EditionImagesView(release: release, edition: edition)
            }
        }
        .confirmationDialog(
            "¿Eliminar edición de \"\(release.title)\"?",
            isPresented: $showingDeleteEditionConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { Task { await deleteEdition() } }
        } message: {
            Text("Se eliminarán también sus temas e imágenes. Esta acción no se puede deshacer.")
        }
    }

    private var header: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.quaternary)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)
            .overlay {
                if let url = selectedEdition.flatMap(coverURL) ?? release.coverURL {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "opticaldisc").font(.system(size: 40)).foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "opticaldisc").font(.system(size: 40)).foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var editionList: some View {
        VStack(spacing: 0) {
            ForEach(release.editions, id: \.id) { edition in
                EditionRow(
                    edition: edition,
                    coverURL: coverURL(of: edition),
                    isSelected: edition.id == selectedEditionID
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedEditionID = edition.id }

                if edition.id != release.editions.last?.id {
                    Divider().padding(.leading, 72)
                }
            }
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func editionMeta(_ edition: Edition) -> some View {
        HStack(spacing: 6) {
            if let country = edition.country { Text(country) }
            if let label = edition.label { Text("·"); Text(label) }
            if let year = edition.release_date?.prefix(4) { Text("·"); Text(year) }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func tracklist(_ tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Temas")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(tracks.sorted(by: { $0.position < $1.position })) { track in
                HStack {
                    Text("\(track.position)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    Text(track.title)
                    Spacer()
                    if let seconds = track.duration_seconds {
                        Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private func coverURL(of edition: Edition) -> URL? {
        guard let cover = edition.images.first(where: { $0.image_type == .front_cover }) else { return nil }
        return URL(string: cover.url)
    }

    private func deleteRelease() async {
        isDeleting = true
        defer { isDeleting = false }
        try? await store.deleteRelease(id: release.id)
        dismiss()
    }

    private func deleteEdition() async {
        guard let edition = selectedEdition else { return }
        isDeletingEdition = true
        defer { isDeletingEdition = false }
        try? await store.deleteEdition(releaseID: release.id, editionID: edition.id)
        release.editions.removeAll { $0.id == edition.id }
        selectedEditionID = release.displayEdition?.id
    }

    private func refresh() async {
        guard let fresh = try? await store.fetchRelease(id: release.id) else { return }
        release = fresh
        if selectedEditionID == nil || !release.editions.contains(where: { $0.id == selectedEditionID }) {
            selectedEditionID = release.displayEdition?.id
        }
    }
}

// MARK: - Fila de edición

private struct EditionRow: View {
    let edition: Edition
    let coverURL: URL?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Miniatura de portada
            AsyncImage(url: coverURL) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "opticaldisc")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Metadatos
            VStack(alignment: .leading, spacing: 2) {
                Text(edition.edition_name ?? edition.country ?? "Edición")
                    .font(.body)
                    .lineLimit(1)

                let subtitle = [
                    edition.format?.displayName,
                    edition.release_date.map { String($0.prefix(4)) },
                    edition.label
                ].compactMap { $0 }.joined(separator: " · ")

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        ReleaseDetailView(release: Release(
            id: 1,
            title: "Tubular Bells",
            release_type: .studio,
            created_at: .now,
            editions: []
        ))
    }
    .environment(AuthSession(initialState: .signedOut))
}
