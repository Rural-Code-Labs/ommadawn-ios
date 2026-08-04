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

private extension Set {
    mutating func toggle(_ member: Element) {
        if contains(member) { remove(member) } else { insert(member) }
    }
}

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
        editionImages.sorted { $0.position < $1.position }
    }

    private var editionImageURLs: [URL] {
        sortedEditionImages.compactMap { URL(string: $0.url) }
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

                    if let desc = release.description, !desc.isEmpty {
                        ExpandableMarkdownText(text: desc, sheetTitle: "Descripción")
                            .font(.body)
                    }

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
                            if let credits = edition.credits, !credits.isEmpty {
                                Divider()
                                MarkdownInfoSection(title: "Créditos", text: credits)
                            }
                            if let notes = edition.notes, !notes.isEmpty {
                                Divider()
                                MarkdownInfoSection(title: "Notas", text: notes)
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
                        .foregroundStyle(.tint)
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
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 4) {
            if let country = edition.country {
                GridRow {
                    Text("País")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.leading)
                    Text(Country.find(country)?.displayName ?? country)
                }
            }
            if let label = edition.label, !label.isEmpty {
                GridRow {
                    Text("Sello").foregroundStyle(.secondary)
                    Text(label)
                }
            }
            if let dateStr = edition.release_date {
                GridRow {
                    Text("Publicación").foregroundStyle(.secondary)
                    Text(formattedDate(dateStr))
                }
            }
            if let format = edition.format {
                GridRow {
                    Text("Formato").foregroundStyle(.secondary)
                    Text(format.displayName)
                }
            }
            if let cat = edition.catalog_number, !cat.isEmpty {
                GridRow {
                    Text("Cat.").foregroundStyle(.secondary)
                    Text(cat)
                }
            }
        }
        .font(.subheadline)
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

    private func formattedDate(_ string: String) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es")
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: string) else { return string }
        df.dateStyle = .long
        df.timeStyle = .none
        return df.string(from: date)
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

// MARK: - Texto Markdown colapsable (abre hoja modal)

private struct ExpandableMarkdownText: View {
    let text: String
    let sheetTitle: String
    @State private var showingSheet = false

    var body: some View {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)

        VStack(alignment: .leading, spacing: 6) {
            Text(attributed)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Leer más") { showingSheet = true }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tint)
                .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingSheet) {
            MarkdownFullTextSheet(title: sheetTitle, text: text)
        }
    }
}

// MARK: - Hoja con el texto completo

private struct MarkdownFullTextSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Sección de información Markdown con cabecera

private struct MarkdownInfoSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ExpandableMarkdownText(text: text, sheetTitle: title)
                .font(.body)
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
            .overlay(alignment: .bottomTrailing) {
                if let flag = Country.find(edition.country)?.flag {
                    Text(flag)
                        .font(.system(size: 20))
                }
            }

            // Metadatos
            VStack(alignment: .leading, spacing: 2) {
                Text(edition.edition_name ?? Country.find(edition.country)?.displayName ?? edition.country ?? "Edición")
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

    @State private var showingFilters = false
    @State private var selectedFormats: Set<String> = []
    @State private var selectedYears: Set<String> = []
    @State private var selectedLabels: Set<String> = []
    @State private var selectedCountries: Set<String> = []

    private func coverURL(of edition: Edition) -> URL? {
        guard let cover = edition.images.first(where: { $0.image_type == .front_cover }) else { return nil }
        return URL(string: cover.url)
    }

    private var availableFormats: [String] {
        Array(Set(release.editions.compactMap { $0.format?.displayName })).sorted()
    }

    private var availableYears: [String] {
        Array(Set(release.editions.compactMap {
            $0.release_date.map { String($0.prefix(4)) }
        })).sorted()
    }

    private var availableLabels: [String] {
        Array(Set(release.editions.compactMap { $0.label })).sorted()
    }

    private var availableCountries: [String] {
        Array(Set(release.editions.compactMap { $0.country })).sorted {
            let a = Country.find($0)?.name ?? $0
            let b = Country.find($1)?.name ?? $1
            return a.localizedStandardCompare(b) == .orderedAscending
        }
    }

    private var activeFilterCount: Int {
        (selectedFormats.isEmpty ? 0 : 1) +
        (selectedYears.isEmpty ? 0 : 1) +
        (selectedLabels.isEmpty ? 0 : 1) +
        (selectedCountries.isEmpty ? 0 : 1)
    }

    private var filteredEditions: [Edition] {
        release.editions.filter { edition in
            let formatOK = selectedFormats.isEmpty ||
                edition.format.map { selectedFormats.contains($0.displayName) } == true
            let yearOK = selectedYears.isEmpty ||
                edition.release_date.map { selectedYears.contains(String($0.prefix(4))) } == true
            let labelOK = selectedLabels.isEmpty ||
                edition.label.map { selectedLabels.contains($0) } == true
            let countryOK = selectedCountries.isEmpty ||
                edition.country.map { selectedCountries.contains($0) } == true
            return formatOK && yearOK && labelOK && countryOK
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredEditions.isEmpty {
                    ContentUnavailableView(
                        "Sin resultados",
                        systemImage: "magnifyingglass",
                        description: Text("Ninguna edición coincide con los filtros activos.")
                    )
                } else {
                    List {
                        ForEach(filteredEditions, id: \.id) { edition in
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
                }
            }
            .navigationTitle("Ediciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingFilters = true } label: {
                        Image(systemName: activeFilterCount > 0
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                EditionFilterSheet(
                    availableFormats: availableFormats,
                    availableYears: availableYears,
                    availableLabels: availableLabels,
                    availableCountries: availableCountries,
                    selectedFormats: $selectedFormats,
                    selectedYears: $selectedYears,
                    selectedLabels: $selectedLabels,
                    selectedCountries: $selectedCountries
                )
            }
        }
    }
}

// MARK: - Hoja de filtros

private struct EditionFilterSheet: View {
    let availableFormats: [String]
    let availableYears: [String]
    let availableLabels: [String]
    let availableCountries: [String]
    @Binding var selectedFormats: Set<String>
    @Binding var selectedYears: Set<String>
    @Binding var selectedLabels: Set<String>
    @Binding var selectedCountries: Set<String>
    @Environment(\.dismiss) private var dismiss

    private var hasActiveFilters: Bool {
        !selectedFormats.isEmpty || !selectedYears.isEmpty ||
        !selectedLabels.isEmpty || !selectedCountries.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if !availableFormats.isEmpty {
                    Section("Tipo") {
                        ForEach(availableFormats, id: \.self) { format in
                            FilterRow(
                                title: format,
                                isSelected: selectedFormats.contains(format)
                            ) {
                                selectedFormats.toggle(format)
                            }
                        }
                    }
                }
                if !availableYears.isEmpty {
                    Section("Año") {
                        ForEach(availableYears, id: \.self) { year in
                            FilterRow(
                                title: year,
                                isSelected: selectedYears.contains(year)
                            ) {
                                selectedYears.toggle(year)
                            }
                        }
                    }
                }
                if !availableLabels.isEmpty {
                    Section("Sello") {
                        ForEach(availableLabels, id: \.self) { label in
                            FilterRow(
                                title: label,
                                isSelected: selectedLabels.contains(label)
                            ) {
                                selectedLabels.toggle(label)
                            }
                        }
                    }
                }
                if !availableCountries.isEmpty {
                    Section("País") {
                        ForEach(availableCountries, id: \.self) { code in
                            let country = Country.find(code)
                            FilterRow(
                                title: country?.displayName ?? code,
                                isSelected: selectedCountries.contains(code)
                            ) {
                                selectedCountries.toggle(code)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Restablecer") {
                        selectedFormats = []
                        selectedYears = []
                        selectedLabels = []
                        selectedCountries = []
                    }
                    .disabled(!hasActiveFilters)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

private struct FilterRow: View {
    let title: String
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
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
