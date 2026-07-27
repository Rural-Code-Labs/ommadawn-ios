//
//  AvatarUpload.swift
//  OmmadawnAPI
//
//  Sube el avatar del usuario autenticado construyendo el part multipart a
//  mano, en vez de usar el case `.file` que genera el plugin.
//
//  El contrato declara el fichero como `contentMediaType: application/octet-stream`,
//  y el generador usa ESE valor literal como `Content-Type` del part — pero
//  la API valida el tipo real de la imagen (`image/jpeg`/`png`/`webp`) contra
//  ese header, así que subiendo por el case generado siempre respondería 422
//  (formato no soportado), fuera cual fuera la imagen. El case `.undocumented`
//  permite construir el part con el `Content-Type` real.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

public extension Client {
    /// Sube (o sustituye) el avatar del usuario autenticado.
    ///
    /// - Parameters:
    ///   - data: bytes de la imagen (JPEG, PNG o WEBP).
    ///   - mimeType: tipo MIME real de `data` (p. ej. `"image/jpeg"`), el que
    ///     valida la API — no el que declara el contrato para el part.
    ///   - filename: nombre de fichero a enviar (solo informativo).
    func uploadAvatar(
        data: Data,
        mimeType: String,
        filename: String
    ) async throws -> Operations.upload_avatar_api_v1_auth_me_avatar_post.Output {
        var headerFields = HTTPFields()
        headerFields[.contentType] = mimeType
        let part = MultipartRawPart(
            name: "file",
            filename: filename,
            headerFields: headerFields,
            body: HTTPBody(data)
        )
        return try await upload_avatar_api_v1_auth_me_avatar_post(
            .init(body: .multipartForm([.undocumented(part)]))
        )
    }
}
