//
//  EditionEditView.swift
//  ommadawn
//
//  Formulario para crear o editar una Edition.
//  Modo crear: `edition` es nil, body vacío (salvo is_primary=true si es la primera).
//  Modo editar: `edition` viene relleno.
//  En ambos casos llama a `onSave` con la Edition que devuelve la API.
//
//  La tracklist se gestiona como un array local de EditableTrack (sin IDs de API:
//  la posición es el índice + 1). En el PATCH se envía el array completo, lo que
//  permite añadir, eliminar y reordenar en una sola llamada.
//

import SwiftUI
import PhotosUI
import OmmadawnAPI

struct EditionEditView: View {
    let release: Release
    let edition: Edition?
    let onSave: (Edition) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var session

    // MARK: - Metadatos
    @State private var editionName: String
    @State private var countryCode: String?
    @State private var showingCountryPicker = false
    @State private var label: String
    @State private var catalogNumber: String
    @State private var format: EditionFormat?
    @State private var includesDate: Bool
    @State private var releaseDate: Date
    @State private var isPrimary: Bool
    @State private var credits: String
    @State private var notes: String

    // MARK: - Tracklist
    @State private var tracks: [EditableTrack]

    // MARK: - Imágenes (solo en modo edición)
    @State private var images: [ReleaseImage]
    @State private var selectedImageType: ReleaseImageType = .front_cover
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var deletingImageID: Int?
    @State private var movingImageID: Int?

    // MARK: - Editores Markdown
    @State private var creditsController = MarkdownEditorController()
    @State private var notesController   = MarkdownEditorController()
    @State private var showingCheatsheet = false

    // MARK: - Estado de UI
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(release: Release, edition: Edition? = nil, onSave: @escaping (Edition) -> Void) {
        self.release = release
        self.edition = edition
        self.onSave = onSave

        _editionName   = State(initialValue: edition?.edition_name ?? "")
        _countryCode   = State(initialValue: edition?.country)
        _label         = State(initialValue: edition?.label ?? "")
        _catalogNumber = State(initialValue: edition?.catalog_number ?? "")
        _format        = State(initialValue: edition?.format)
        _isPrimary     = State(initialValue: edition?.is_primary ?? (release.editions.isEmpty))
        _credits       = State(initialValue: edition?.credits ?? "")
        _notes         = State(initialValue: edition?.notes ?? "")

        if let dateStr = edition?.release_date,
           let parsed = Self.dateFormatter.date(from: dateStr) {
            _includesDate = State(initialValue: true)
            _releaseDate  = State(initialValue: parsed)
        } else {
            _includesDate = State(initialValue: false)
            _releaseDate  = State(initialValue: Date.now)
        }

        _tracks = State(initialValue: edition?.tracks
            .sorted { $0.position < $1.position }
            .map { EditableTrack(from: $0) } ?? [])
        _images = State(initialValue: edition?.images ?? [])
    }

    private var store: DiscographyStore { DiscographyStore(client: session.client) }
    private var isEditing: Bool { edition != nil }

    var body: some View {
        NavigationStack {
            Form {
                metadataSection
                MarkdownEditorSection(
                    "Créditos",
                    text: $credits,
                    controller: creditsController,
                    onCheatsheet: { showingCheatsheet = true }
                )
                MarkdownEditorSection(
                    "Notas",
                    text: $notes,
                    controller: notesController,
                    onCheatsheet: { showingCheatsheet = true }
                )
                tracklistSection
                if isEditing { imagesSection }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar edición" : "Nueva edición")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCheatsheet) { MarkdownCheatsheetView() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar") { Task { await save() } }
                    }
                }
            }
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                Task { await uploadPhoto(item) }
            }
            .disabled(isSaving)
        }
    }

    // MARK: - Secciones

    private var metadataSection: some View {
        Section("Datos") {
            LabeledContent("Nombre de edición") {
                TextField("Edición original, Remasterizada…", text: $editionName)
                    .multilineTextAlignment(.trailing)
            }
            Button { showingCountryPicker = true } label: {
                LabeledContent("País") {
                    if let c = Country.find(countryCode) {
                        Text(c.displayName).foregroundStyle(.primary)
                    } else {
                        Text("Sin especificar").foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)
            .sheet(isPresented: $showingCountryPicker) {
                CountryPickerView(selectedCode: $countryCode)
            }
            LabeledContent("Sello") {
                TextField("Virgin, Polydor…", text: $label)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Núm. catálogo") {
                TextField("V2001, OVED 1…", text: $catalogNumber)
                    .multilineTextAlignment(.trailing)
            }
            Picker("Formato", selection: $format) {
                Text("Sin especificar").tag(EditionFormat?.none)
                ForEach(EditionFormat.allCases, id: \.self) { f in
                    Text(f.displayName).tag(EditionFormat?.some(f))
                }
            }
            Toggle("Fecha de lanzamiento", isOn: $includesDate.animation())
            if includesDate {
                DatePicker(
                    "Fecha",
                    selection: $releaseDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .labelsHidden()
            }
            Toggle("Edición principal", isOn: $isPrimary)
        }
    }

    private var tracklistSection: some View {
        Section("Temas") {
            ForEach($tracks) { $track in
                TrackEditRow(track: $track) {
                    tracks.removeAll { $0.id == track.id }
                }
            }
            Button {
                tracks.append(EditableTrack())
            } label: {
                Label("Añadir tema", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Imágenes

    private var imagesSection: some View {
        let sorted   = images.sorted { $0.position < $1.position }
        let hasFront = images.contains { $0.image_type == .front_cover }
        let hasBack  = images.contains { $0.image_type == .back_cover }
        return Group {
            Section("Imágenes") {
                if sorted.isEmpty {
                    Text("Sin imágenes todavía")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, image in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: image.url)) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.secondary.opacity(0.2)
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(imageTypeName(image.image_type)).font(.body)
                                Text(image.url.components(separatedBy: "/").last ?? "")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if movingImageID == image.id || deletingImageID == image.id {
                                ProgressView()
                            } else {
                                if index > 0 {
                                    Button { Task { await moveImage(image, direction: .up) } } label: {
                                        Image(systemName: "chevron.up")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(isUploadingImage || movingImageID != nil || deletingImageID != nil)
                                }
                                if index < sorted.count - 1 {
                                    Button { Task { await moveImage(image, direction: .down) } } label: {
                                        Image(systemName: "chevron.down")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(isUploadingImage || movingImageID != nil || deletingImageID != nil)
                                }
                                Button { Task { await deleteImage(image) } } label: {
                                    Image(systemName: "trash").foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .disabled(isUploadingImage || movingImageID != nil)
                            }
                        }
                    }
                }
            }

            Section("Añadir imagen") {
                Picker("Tipo", selection: $selectedImageType) {
                    if !hasFront {
                        Text("Portada").tag(ReleaseImageType.front_cover)
                    }
                    if !hasBack {
                        Text("Contraportada").tag(ReleaseImageType.back_cover)
                    }
                    Text("Otra").tag(ReleaseImageType.other)
                }
                .onChange(of: hasFront) { _, _ in adjustImageType(hasFront: hasFront, hasBack: hasBack) }
                .onChange(of: hasBack)  { _, _ in adjustImageType(hasFront: hasFront, hasBack: hasBack) }
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label(
                        isUploadingImage ? "Subiendo…" : "Subir imagen",
                        systemImage: "photo.badge.plus"
                    )
                }
                .disabled(isUploadingImage)
            }
        }
    }

    // Si el tipo seleccionado ya no está disponible (porque se acaba de subir
    // una portada o contraportada), cambia automáticamente a "Otra".
    private func adjustImageType(hasFront: Bool, hasBack: Bool) {
        if selectedImageType == .front_cover && hasFront { selectedImageType = .other }
        if selectedImageType == .back_cover  && hasBack  { selectedImageType = .other }
    }

    private func imageTypeName(_ type: ReleaseImageType) -> String {
        switch type {
        case .front_cover: "Portada"
        case .back_cover:  "Contraportada"
        case .other:       "Otra"
        }
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        guard let edition else { return }
        isUploadingImage = true
        defer { isUploadingImage = false; photoPickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            guard let mimeType = Self.mimeType(for: data) else {
                errorMessage = "Formato no soportado. Usa JPEG, PNG o WEBP."
                return
            }
            let ext = Self.fileExtension(for: mimeType)
            let newImage = try await store.uploadEditionImage(
                releaseID: release.id, editionID: edition.id,
                data: data, mimeType: mimeType,
                filename: "image\(ext)", imageType: selectedImageType
            )
            images.append(newImage)
        } catch let e as DiscographyError { errorMessage = message(for: e) }
        catch { errorMessage = "No se pudo subir la imagen. Inténtalo de nuevo." }
    }

    private func moveImage(_ image: ReleaseImage, direction: Components.Schemas.ImageMoveRequest.directionPayload) async {
        guard let edition else { return }
        movingImageID = image.id
        defer { movingImageID = nil }
        do {
            images = try await store.moveEditionImage(
                releaseID: release.id, editionID: edition.id, imageID: image.id, direction: direction
            )
        } catch let e as DiscographyError { errorMessage = message(for: e) }
        catch { errorMessage = "No se pudo mover la imagen. Inténtalo de nuevo." }
    }

    private func deleteImage(_ image: ReleaseImage) async {
        guard let edition else { return }
        deletingImageID = image.id
        defer { deletingImageID = nil }
        do {
            try await store.deleteEditionImage(
                releaseID: release.id, editionID: edition.id, imageID: image.id
            )
            images.removeAll { $0.id == image.id }
        } catch let e as DiscographyError { errorMessage = message(for: e) }
        catch { errorMessage = "No se pudo eliminar la imagen. Inténtalo de nuevo." }
    }

    private static func mimeType(for data: Data) -> String? {
        let jpeg: [UInt8] = [0xFF, 0xD8, 0xFF]
        let png:  [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        if data.starts(with: jpeg) { return "image/jpeg" }
        if data.starts(with: png)  { return "image/png" }
        if data.count >= 12,
           data[data.startIndex..<data.startIndex + 4].elementsEqual(Array("RIFF".utf8)),
           data[data.startIndex + 8..<data.startIndex + 12].elementsEqual(Array("WEBP".utf8)) {
            return "image/webp"
        }
        return nil
    }

    private static func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": ".jpg"
        case "image/png":  ".png"
        case "image/webp": ".webp"
        default: ""
        }
    }

    // MARK: - Guardar

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let payload = EditionPayload(
            editionName: editionName,
            country: countryCode,
            label: label,
            catalogNumber: catalogNumber,
            releaseDate: includesDate ? Self.dateFormatter.string(from: releaseDate) : nil,
            format: format,
            credits: credits,
            notes: notes,
            isPrimary: isPrimary,
            tracks: tracks
        )

        do {
            let saved: Edition
            if let existing = edition {
                saved = try await store.updateEdition(releaseID: release.id, editionID: existing.id, data: payload)
            } else {
                saved = try await store.createEdition(releaseID: release.id, data: payload)
            }
            onSave(saved)
            dismiss()
        } catch let error as DiscographyError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "No se pudo guardar. Inténtalo de nuevo."
        }
    }

    private func message(for error: DiscographyError) -> String {
        switch error {
        case .forbidden:          "No tienes permisos para realizar esta acción."
        case .notFound:           "La edición o el disco ya no existe."
        case .imageTooLarge:      "La imagen supera el tamaño máximo permitido."
        case .unexpected(let c):  "Error del servidor (\(c))."
        case .network:            "Comprueba tu conexión e inténtalo de nuevo."
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Fila de tema editable

private struct TrackEditRow: View {
    @Binding var track: EditableTrack
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)

            TextField("Título del tema", text: $track.title)

            TextField("M:SS", text: $track.durationText)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(width: 54)
                .keyboardType(.numbersAndPunctuation)
        }
    }
}

// MARK: - Preview

#Preview("Crear") {
    EditionEditView(
        release: Release(id: 1, title: "Tubular Bells", release_type: .studio, created_at: .now, editions: []),
        onSave: { _ in }
    )
    .environment(AuthSession(initialState: .signedOut))
}

#Preview("Editar") {
    let track = Track(id: 1, position: 1, title: "Tubular Bells Part One", duration_seconds: 1530)
    let edition = Edition(
        id: 1, country: "UK", label: "Virgin", edition_name: nil,
        catalog_number: "V2001", release_date: "1973-05-25",
        format: .vinyl, credits: nil, notes: nil,
        is_primary: true, tracks: [track], images: []
    )
    let release = Release(id: 1, title: "Tubular Bells", release_type: .studio, created_at: .now, editions: [edition])
    EditionEditView(release: release, edition: edition, onSave: { _ in })
        .environment(AuthSession(initialState: .signedOut))
}
