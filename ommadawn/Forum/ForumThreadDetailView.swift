//
//  ForumThreadDetailView.swift
//  ommadawn
//
//  Detalle de un hilo: cuerpo + comentarios, todo en Markdown, y un
//  compositor de comentario nuevo al final con el mismo editor.
//

import SwiftUI
import OmmadawnAPI

struct ForumThreadDetailView: View {
    let threadID: Int
    let store: ForumStore

    @State private var thread: ForumThreadDetail?
    @State private var isLoading = false
    @State private var loadErrorMessage: String?

    @State private var commentText = ""
    @State private var commentController = MarkdownEditorController()
    @State private var isSubmittingComment = false
    @State private var commentErrorMessage: String?
    @State private var showingVerifyEmail = false
    @State private var showingCheatsheet = false

    var body: some View {
        content
            .navigationTitle(thread?.title ?? "Hilo")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && thread == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadErrorMessage, thread == nil {
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.slash")
            } description: {
                Text(loadErrorMessage)
            } actions: {
                Button("Reintentar") { Task { await load() } }
            }
        } else if let thread {
            List {
                Section {
                    threadHeader(thread)
                    MarkdownBlock(text: thread.body)
                }

                Section("Comentarios (\(thread.comments.count))") {
                    if thread.comments.isEmpty {
                        Text("Todavía no hay comentarios.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(thread.comments) { comment in
                            commentRow(comment)
                        }
                    }
                }

                if thread.status == .open {
                    if let commentErrorMessage {
                        Section {
                            Text(commentErrorMessage).foregroundStyle(.red)
                            if showingVerifyEmail {
                                NavigationLink("Verificar email") {
                                    VerifyEmailView()
                                }
                            }
                        }
                    }

                    MarkdownEditorSection(
                        "Comentar",
                        text: $commentText,
                        controller: commentController,
                        editorHeight: 120
                    ) {
                        showingCheatsheet = true
                    }

                    Section {
                        if isSubmittingComment {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Button("Enviar comentario") { Task { await submitComment() } }
                                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                } else {
                    Section {
                        Label("Este hilo está \(thread.status.displayName.lowercased()) — ya no admite comentarios.", systemImage: "lock")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingCheatsheet) {
                MarkdownCheatsheetView()
            }
            .sheet(isPresented: $commentController.showingPreview) {
                MarkdownPreviewSheet(title: commentController.previewTitle, text: commentController.previewText)
            }
        }
    }

    private func threadHeader(_ thread: ForumThreadDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(thread.title)
                .font(.title3.bold())
            HStack(spacing: 8) {
                Text(thread.status.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(thread.status.tintColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(thread.status.tintColor)
                Text("Por \(thread.author_username) · \(thread.created_at.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func commentRow(_ comment: ForumComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(comment.author_username) · \(comment.created_at.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            MarkdownBlock(text: comment.body)
        }
    }

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        defer { isLoading = false }
        do {
            thread = try await store.fetchThread(id: threadID)
        } catch {
            loadErrorMessage = "Comprueba tu conexión e inténtalo de nuevo."
        }
    }

    private func submitComment() async {
        commentErrorMessage = nil
        showingVerifyEmail = false
        isSubmittingComment = true
        defer { isSubmittingComment = false }
        do {
            let comment = try await store.addComment(
                threadID: threadID,
                body: commentText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            thread?.comments.append(comment)
            commentText = ""
        } catch ForumError.emailNotVerified {
            commentErrorMessage = "Verifica tu email para poder comentar."
            showingVerifyEmail = true
        } catch ForumError.sessionExpired {
            commentErrorMessage = "Tu sesión ha caducado. Vuelve a entrar e inténtalo de nuevo."
        } catch ForumError.invalidData {
            commentErrorMessage = "Revisa el comentario e inténtalo de nuevo."
        } catch {
            commentErrorMessage = "No se pudo enviar el comentario. Inténtalo de nuevo."
        }
    }
}
