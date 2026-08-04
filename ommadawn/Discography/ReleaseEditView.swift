//
//  ReleaseEditView.swift
//  ommadawn
//
//  Formulario para crear o editar un Release (título, tipo y descripción).
//  La descripción admite sintaxis Markdown: la toolbar de la sección ofrece
//  atajos para negrita, cursiva y enlace, más un botón de referencia rápida.
//

import SwiftUI
import OmmadawnAPI

struct ReleaseEditView: View {
    let release: Release?
    let onSave: (Release) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var session

    @State private var title: String
    @State private var type: ReleaseType
    @State private var description: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingCheatsheet = false

    @State private var markdownController = MarkdownEditorController()

    init(release: Release? = nil, onSave: @escaping (Release) -> Void) {
        self.release = release
        self.onSave = onSave
        _title       = State(initialValue: release?.title ?? "")
        _type        = State(initialValue: release?.release_type ?? .studio)
        _description = State(initialValue: release?.description ?? "")
    }

    private var store: DiscographyStore { DiscographyStore(client: session.client) }
    private var isEditing: Bool { release != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    LabeledContent("Título") {
                        TextField("", text: $title)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Tipo", selection: $type) {
                        ForEach(ReleaseType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                }

                MarkdownEditorSection(
                    "Descripción",
                    text: $description,
                    controller: markdownController,
                    editorHeight: 220,
                    onCheatsheet: { showingCheatsheet = true }
                )

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar disco" : "Nuevo disco")
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
                            .disabled(!canSave)
                    }
                }
            }
            .disabled(isSaving)
            .sheet(isPresented: $showingCheatsheet) {
                MarkdownCheatsheetView()
            }
            .sheet(isPresented: Binding(
                get: { markdownController.showingPreview },
                set: { markdownController.showingPreview = $0 }
            )) {
                MarkdownPreviewSheet(title: markdownController.previewTitle, text: markdownController.previewText)
            }
        }
    }

    // MARK: - Guardar

    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let saved: Release
            if let existing = release {
                saved = try await store.updateRelease(
                    id: existing.id, title: trimmed, type: type,
                    description: desc.isEmpty ? nil : desc
                )
            } else {
                saved = try await store.createRelease(
                    title: trimmed, type: type,
                    description: desc.isEmpty ? nil : desc
                )
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
        case .forbidden:            "No tienes permisos para realizar esta acción."
        case .notFound:             "El disco ya no existe."
        case .imageTooLarge:        "La imagen supera el tamaño máximo permitido."
        case .unexpected(let code): "Error del servidor (\(code))."
        case .network:              "Comprueba tu conexión e inténtalo de nuevo."
        }
    }
}

#Preview("Crear") {
    ReleaseEditView { _ in }
        .environment(AuthSession(initialState: .signedOut))
}

#Preview("Editar") {
    ReleaseEditView(release: Release(
        id: 1, title: "Tubular Bells", release_type: .studio,
        description: "El álbum debut de Mike Oldfield, grabado en 1973.",
        created_at: .now, editions: []
    )) { _ in }
    .environment(AuthSession(initialState: .signedOut))
}
