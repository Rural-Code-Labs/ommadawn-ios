//
//  AccountProfileView.swift
//  ommadawn
//
//  Panel de perfil: avatar (subir/quitar) y datos editables (nombre, país,
//  ciudad, fecha de nacimiento). Se abre al pulsar el nombre en AccountMenu.
//
//  Lee el usuario en vivo desde AuthSession (no por parámetro) para que el
//  avatar se refresque solo tras subir/quitar una foto. Los campos del
//  formulario, en cambio, se siembran UNA vez al aparecer (`hasLoadedForm`):
//  si se releyeran del usuario en cada cambio de sesión, se perdería lo que
//  la persona esté escribiendo cada vez que el avatar se actualiza.
//
//  Limitación conocida: el campo de nombre/país/ciudad se puede rellenar
//  pero no "vaciar" desde aquí (un campo vacío no se envía, por cómo
//  funciona el PATCH parcial de la API — ver `saveProfile`). Editarlo para
//  borrarlo del todo queda para más adelante si hace falta.
//

import SwiftUI
import PhotosUI
import OmmadawnAPI

struct AccountProfileView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var hasLoadedForm = false
    @State private var fullName = ""
    @State private var countryCode: String?
    @State private var showingCountryPicker = false
    @State private var city = ""
    @State private var includesBirthDate = false
    @State private var birthDate = Date.now

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var user: User? {
        guard case .signedIn(let user) = session.state else { return nil }
        return user
    }

    var body: some View {
        NavigationStack {
            Form {
                if let user {
                    avatarSection(for: user)
                }

                Section("Datos") {
                    if let user {
                        LabeledContent("Usuario", value: user.username)
                            .foregroundStyle(.primary)
                    }
                    LabeledContent("Nombre completo") {
                        TextField("", text: $fullName)
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
                    LabeledContent("Ciudad") {
                        TextField("", text: $city)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Fecha de nacimiento", isOn: $includesBirthDate.animation())
                    if includesBirthDate {
                        DatePicker("Fecha de nacimiento", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar") { Task { await saveProfile() } }
                    }
                }
            }
            .disabled(isSaving)
            .task {
                guard !hasLoadedForm, let user else { return }
                fullName = user.full_name ?? ""
                countryCode = user.country
                city = user.city ?? ""
                if let parsed = user.birth_date.flatMap(Self.dateOnlyFormatter.date(from:)) {
                    birthDate = parsed
                    includesBirthDate = true
                }
                hasLoadedForm = true
            }
        }
    }

    // MARK: - Avatar

    private func avatarSection(for user: User) -> some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    ZStack {
                        AccountAvatarView(user: user, size: 100)
                        if isUploadingAvatar {
                            ProgressView()
                        }
                    }

                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        Text(user.avatarURL == nil ? "Elegir foto" : "Cambiar foto")
                    }
                    .disabled(isUploadingAvatar)

                    if user.avatarURL != nil {
                        Button("Quitar foto", role: .destructive) {
                            Task { await deleteAvatar() }
                        }
                        .disabled(isUploadingAvatar)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await uploadPhoto(newItem) }
        }
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        errorMessage = nil
        isUploadingAvatar = true
        defer { isUploadingAvatar = false; photoPickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "No se pudo leer la imagen."
                return
            }
            guard let mimeType = Self.mimeType(for: data) else {
                errorMessage = "Formato de imagen no soportado (usa JPEG, PNG o WEBP)."
                return
            }
            try await session.uploadAvatar(data: data, mimeType: mimeType, filename: "avatar\(Self.fileExtension(for: mimeType))")
        } catch let error as ProfileError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "No se pudo subir la imagen. Inténtalo de nuevo."
        }
    }

    private func deleteAvatar() async {
        errorMessage = nil
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            try await session.deleteAvatar()
        } catch let error as ProfileError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "No se pudo quitar la foto. Inténtalo de nuevo."
        }
    }

    // MARK: - Perfil

    private func saveProfile() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await session.updateProfile(
                fullName: trimmedName.isEmpty ? nil : trimmedName,
                country: countryCode,
                city: trimmedCity.isEmpty ? nil : trimmedCity,
                birthDate: includesBirthDate ? Self.dateOnlyFormatter.string(from: birthDate) : nil
            )
            dismiss()
        } catch let error as ProfileError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "No se pudo guardar. Inténtalo de nuevo."
        }
    }

    // MARK: - Privado

    private func message(for error: ProfileError) -> String {
        switch error {
        case .invalidData:
            "Revisa los datos introducidos."
        case .imageTooLarge:
            "La imagen supera el tamaño máximo permitido (10 MB)."
        case .sessionExpired:
            "Tu sesión ha caducado. Vuelve a iniciar sesión."
        case .unexpected(let statusCode):
            "Error del servidor (\(statusCode)). Inténtalo más tarde."
        case .network:
            "No se pudo conectar. Comprueba tu conexión."
        }
    }

    /// Formato `yyyy-MM-dd` (campo `date` del contrato, sin hora ni zona).
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Identifica JPEG/PNG/WEBP por sus primeros bytes — el `PhotosPicker`
    /// no expone el tipo MIME real de forma directa, y es justo lo que
    /// valida la API (ver AvatarUpload.swift, en el paquete OmmadawnAPI).
    private static func mimeType(for data: Data) -> String? {
        let jpegMagic: [UInt8] = [0xFF, 0xD8, 0xFF]
        let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        if data.starts(with: jpegMagic) { return "image/jpeg" }
        if data.starts(with: pngMagic) { return "image/png" }
        if data.count >= 12, data[data.startIndex..<data.startIndex + 4].elementsEqual(Array("RIFF".utf8)),
           data[data.startIndex + 8..<data.startIndex + 12].elementsEqual(Array("WEBP".utf8)) {
            return "image/webp"
        }
        return nil
    }

    private static func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": ".jpg"
        case "image/png": ".png"
        case "image/webp": ".webp"
        default: ""
        }
    }
}

#Preview {
    AccountProfileView()
        .environment(AuthSession(initialState: .signedIn(User(
            id: 1,
            username: "rafatest",
            email: "rafa@example.com",
            full_name: "Rafa García",
            theme_preference: .system,
            is_active: true,
            is_admin: false,
            is_super_admin: false,
            created_at: .now
        ))))
}
