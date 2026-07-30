//
//  ImageUpload.swift
//  OmmadawnAPI
//
//  Sube una imagen de portada/contraportada a una edición construyendo
//  los parts multipart a mano — mismo motivo que AvatarUpload.swift:
//  el generador usa `application/octet-stream` literal como Content-Type
//  del part de fichero, pero la API valida el tipo real de la imagen.
//
//  El formulario tiene dos parts:
//   1. `image_type` — campo de texto (front_cover / back_cover / other).
//   2. `file`       — binario con el Content-Type real de la imagen.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

public extension Client {
    /// Sube una imagen a una edición concreta.
    ///
    /// - Parameters:
    ///   - releaseID:  ID de la obra.
    ///   - editionID:  ID de la edición.
    ///   - data:       bytes de la imagen (JPEG, PNG o WEBP).
    ///   - mimeType:   tipo MIME real (p. ej. `"image/jpeg"`).
    ///   - filename:   nombre de fichero a enviar (solo informativo).
    ///   - imageType:  tipo de imagen según el contrato.
    func uploadEditionImage(
        releaseID: Int,
        editionID: Int,
        data: Data,
        mimeType: String,
        filename: String,
        imageType: Components.Schemas.ImageType
    ) async throws -> Operations.upload_image_api_v1_discography_releases__release_id__editions__edition_id__images_post.Output {
        // Part 1: image_type como campo de texto
        var textHeaders = HTTPFields()
        textHeaders[.contentType] = "text/plain"
        let typePart = MultipartRawPart(
            name: "image_type",
            filename: nil,
            headerFields: textHeaders,
            body: HTTPBody(imageType.rawValue.data(using: .utf8) ?? Data())
        )

        // Part 2: fichero con el MIME real
        var fileHeaders = HTTPFields()
        fileHeaders[.contentType] = mimeType
        let filePart = MultipartRawPart(
            name: "file",
            filename: filename,
            headerFields: fileHeaders,
            body: HTTPBody(data)
        )

        return try await upload_image_api_v1_discography_releases__release_id__editions__edition_id__images_post(
            .init(
                path: .init(release_id: releaseID, edition_id: editionID),
                body: .multipartForm([.undocumented(typePart), .undocumented(filePart)])
            )
        )
    }
}
