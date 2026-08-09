//
//  ForumThreadComposeView.swift
//  ommadawn
//
//  Hoja para abrir un hilo nuevo. El cuerpo se escribe en Markdown con el
//  mismo editor que ya usan ReleaseEditView/EditionEditView (Fase 4).
//

import SwiftUI
import OmmadawnAPI

struct ForumThreadComposeView: View {
    let store: ForumStore
    let subforumId: Int
    let entityType: ForumEntityType?
    let entityId: Int?
    var onCreated: ((ForumThreadDetail) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""
    @State private var bodyController = MarkdownEditorController()
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showingCheatsheet = false
    @State private var showingVerifyEmail = false

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título", text: $title)
                }

                MarkdownEditorSection(
                    "Mensaje",
                    text: $bodyText,
                    controller: bodyController,
                    editorHeight: 200
                ) {
                    showingCheatsheet = true
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                        if showingVerifyEmail {
                            NavigationLink("Verificar email") {
                                VerifyEmailView()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nuevo hilo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Publicar") { Task { await submit() } }
                            .disabled(!isFormValid)
                    }
                }
            }
            .sheet(isPresented: $showingCheatsheet) {
                MarkdownCheatsheetView()
            }
            .sheet(isPresented: $bodyController.showingPreview) {
                MarkdownPreviewSheet(title: bodyController.previewTitle, text: bodyController.previewText)
            }
            .disabled(isSubmitting)
        }
    }

    private func submit() async {
        errorMessage = nil
        showingVerifyEmail = false
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let created = try await store.createThread(
                subforumId: subforumId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                entityType: entityType,
                entityId: entityId
            )
            onCreated?(created)
            dismiss()
        } catch ForumError.emailNotVerified {
            errorMessage = "Verifica tu email para poder participar en el foro."
            showingVerifyEmail = true
        } catch ForumError.subforumRestricted {
            errorMessage = "Solo un administrador puede abrir hilos en este subforo."
        } catch ForumError.sessionExpired {
            errorMessage = "Tu sesión ha caducado. Vuelve a entrar e inténtalo de nuevo."
        } catch ForumError.invalidData {
            errorMessage = "Revisa el título y el mensaje e inténtalo de nuevo."
        } catch ForumError.notFound {
            errorMessage = "No se pudo encontrar dónde publicar este hilo. Inténtalo de nuevo."
        } catch {
            errorMessage = "No se pudo publicar el hilo. Inténtalo de nuevo."
        }
    }
}
