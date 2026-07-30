//
//  EditionImagesView.swift
//  ommadawn
//
//  Gestión de imágenes (portada, contraportada, otras) de una edición.
//  Las acciones (subir / eliminar) son inmediatas — no hay botón "Guardar".
//  Al cerrar con "Listo", el padre debe refrescar el release para mostrar
//  la portada actualizada.
//

import SwiftUI
import PhotosUI
import OmmadawnAPI

struct EditionImagesView: View {
    let release: Release
    @State private var edition: Edition

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var session

    @State private var selectedImageType: ReleaseImageType = .front_cover
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var deletingID: Int?
    @State private var errorMessage: String?

    init(release: Release, edition: Edition) {
        self.release = release
        _edition = State(initialValue: edition)
    }

    private var store: DiscographyStore { DiscographyStore(client: session.client) }

    var body: some View {
        NavigationStack {
            List {
                currentImagesSection
                uploadSection
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Imágenes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                Task { await uploadPhoto(item) }
            }
        }
    }

    // MARK: - Secciones

    private var currentImagesSection: some View {
        Section("Imágenes actuales") {
            if edition.images.isEmpty {
                Text("Sin imágenes todavía")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(edition.images, id: \.id) { image in
                    ImageRow(image: image, isDeletingID: deletingID) {
                        Task { await deleteImage(image) }
                    }
                }
            }
        }
    }

    private var uploadSection: some View {
        Section("Añadir imagen") {
            Picker("Tipo", selection: $selectedImageType) {
                Text("Portada").tag(ReleaseImageType.front_cover)
                Text("Contraportada").tag(ReleaseImageType.back_cover)
                Text("Otra").tag(ReleaseImageType.other)
            }
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Label(
                    isUploading ? "Subiendo…" : "Elegir foto",
                    systemImage: "photo.badge.plus"
                )
            }
            .disabled(isUploading)
        }
    }

    // MARK: - Acciones

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        errorMessage = nil
        isUploading = true
        defer { isUploading = false; photoPickerItem = nil }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "No se pudo leer la imagen."
                return
            }
            guard let mimeType = mimeType(for: data) else {
                errorMessage = "Formato no soportado. Usa JPEG, PNG o WEBP."
                return
            }
            let ext = fileExtension(for: mimeType)
            let newImage = try await store.uploadEditionImage(
                releaseID: release.id,
                editionID: edition.id,
                data: data,
                mimeType: mimeType,
                filename: "image\(ext)",
                imageType: selectedImageType
            )
            edition.images.append(newImage)
        } catch let error as DiscographyError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "No se pudo subir la imagen. Inténtalo de nuevo."
        }
    }

    private func deleteImage(_ image: ReleaseImage) async {
        errorMessage = nil
        deletingID = image.id
        defer { deletingID = nil }

        do {
            try await store.deleteEditionImage(
                releaseID: release.id,
                editionID: edition.id,
                imageID: image.id
            )
            edition.images.removeAll { $0.id == image.id }
        } catch let error as DiscographyError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "No se pudo eliminar la imagen. Inténtalo de nuevo."
        }
    }

    private func message(for error: DiscographyError) -> String {
        switch error {
        case .forbidden:          "No tienes permisos para esta acción."
        case .notFound:           "La imagen o la edición ya no existe."
        case .imageTooLarge:      "La imagen supera el tamaño máximo permitido."
        case .unexpected(let c):  "Error del servidor (\(c))."
        case .network:            "Comprueba tu conexión e inténtalo de nuevo."
        }
    }

    // MARK: - Helpers MIME

    private func mimeType(for data: Data) -> String? {
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

    private func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": ".jpg"
        case "image/png":  ".png"
        case "image/webp": ".webp"
        default: ""
        }
    }
}

// MARK: - Fila de imagen existente

private struct ImageRow: View {
    let image: ReleaseImage
    let isDeletingID: Int?
    let onDelete: () -> Void

    private var isDeleting: Bool { isDeletingID == image.id }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: image.url)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(imageTypeName(image.image_type))
                    .font(.body)
                Text(image.url.components(separatedBy: "/").last ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isDeleting {
                ProgressView()
            } else {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func imageTypeName(_ type: ReleaseImageType) -> String {
        switch type {
        case .front_cover: "Portada"
        case .back_cover:  "Contraportada"
        case .other:       "Otra"
        }
    }
}
