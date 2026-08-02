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
    @State private var showingEditionList = false
    @State private var imageViewerItem: ImageViewerItem?

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

    private var editionImages: [ReleaseImage] {
        selectedEdition?.images ?? []
    }

    private var sortedEditionImages: [ReleaseImage] {
        editionImages.sorted { imageTypeOrder($0) < imageTypeOrder($1) }
    }

    private var editionImageURLs: [URL] {
        sortedEditionImages.compactMap { URL(string: $0.url) }
    }

    private func imageTypeOrder(_ img: ReleaseImage) -> Int {
        switch img.image_type {
        case .front_cover: return 0
        case .back_cover: return 1
        case .other: return 2
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if !sortedEditionImages.isEmpty {
                    galleryStrip
                }

                VStack(alignment: .leading, spacing: 20) {
                    Text(release.title)
                        .font(.title2.bold())

                    if release.editions.isEmpty {
                        ContentUnavailableView(
                            "Sin ediciones todavía",
                            systemImage: "circle.dashed",
                            description: Text("Esta obra aún no tiene ninguna edición publicada.")
                        )
                    } else {
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
        }
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await refresh() }
        .fullScreenCover(item: $imageViewerItem) { item in
            ImageViewerView(images: item.images, selectedIndex: item.startIndex)
        }
        .sheet(isPresented: $showingEditionList) {
            EditionListSheet(
                release: release,
                selectedEditionID: $selectedEditionID
            )
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
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                if let url = selectedEdition.flatMap(coverURL) ?? release.coverURL {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "opticaldisc").font(.system(size: 40)).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !editionImageURLs.isEmpty else { return }
                        let start = sortedEditionImages.firstIndex(where: { $0.image_type == .front_cover }) ?? 0
                        imageViewerItem = ImageViewerItem(images: editionImageURLs, startIndex: start)
                    }
                } else {
                    Image(systemName: "opticaldisc").font(.system(size: 40)).foregroundStyle(.secondary)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if release.editions.count > 1 {
                    Button { showingEditionList = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 13))
                            Text("\(release.editions.count)")
                                .font(.system(size: 13, weight: .semibold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .padding(12)
                }
            }
            .overlay(alignment: .top) {
                HStack(alignment: .center) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.regularMaterial, in: Circle())
                    }

                    Spacer()

                    if isAdmin {
                        Menu {
                            Button { showingEdit = true } label: {
                                Label("Editar disco", systemImage: "pencil")
                            }
                            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                                Label("Eliminar disco", systemImage: "trash")
                            }
                            Divider()
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
                            Group {
                                if isDeleting || isDeletingEdition {
                                    ProgressView()
                                } else {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .background(.regularMaterial, in: Circle())
                        }
                    } else {
                        Color.clear.frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
    }

    private var galleryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(sortedEditionImages.enumerated()), id: \.offset) { index, img in
                    AsyncImage(url: URL(string: img.url)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(width: 80, height: 80)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        imageViewerItem = ImageViewerItem(images: editionImageURLs, startIndex: index)
                    }
                }
            }
        }
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

// MARK: - Hoja de ediciones

private struct EditionListSheet: View {
    let release: Release
    @Binding var selectedEditionID: Int?
    @Environment(\.dismiss) private var dismiss

    private func coverURL(of edition: Edition) -> URL? {
        guard let cover = edition.images.first(where: { $0.image_type == .front_cover }) else { return nil }
        return URL(string: cover.url)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(release.editions, id: \.id) { edition in
                    EditionRow(
                        edition: edition,
                        coverURL: coverURL(of: edition),
                        isSelected: edition.id == selectedEditionID
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedEditionID = edition.id
                        dismiss()
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
            .navigationTitle("Ediciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Modelo para el visor de imágenes

private struct ImageViewerItem: Identifiable {
    let id = UUID()
    let images: [URL]
    let startIndex: Int
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
