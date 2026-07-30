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
import OmmadawnAPI

struct EditionEditView: View {
    let release: Release
    let edition: Edition?
    let onSave: (Edition) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var session

    // MARK: - Metadatos
    @State private var editionName: String
    @State private var country: String
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

    // MARK: - Estado de UI
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(release: Release, edition: Edition? = nil, onSave: @escaping (Edition) -> Void) {
        self.release = release
        self.edition = edition
        self.onSave = onSave

        _editionName   = State(initialValue: edition?.edition_name ?? "")
        _country       = State(initialValue: edition?.country ?? "")
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
    }

    private var store: DiscographyStore { DiscographyStore(client: session.client) }
    private var isEditing: Bool { edition != nil }

    var body: some View {
        NavigationStack {
            Form {
                metadataSection
                detailsSection
                tracklistSection
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar edición" : "Nueva edición")
            .navigationBarTitleDisplayMode(.inline)
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
            LabeledContent("País") {
                TextField("España, UK, US…", text: $country)
                    .multilineTextAlignment(.trailing)
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

    private var detailsSection: some View {
        Section("Detalles") {
            LabeledContent("Créditos") {
                TextField("", text: $credits, axis: .vertical)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3...)
            }
            LabeledContent("Notas") {
                TextField("", text: $notes, axis: .vertical)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3...)
            }
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

    // MARK: - Guardar

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let payload = EditionPayload(
            editionName: editionName,
            country: country,
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
