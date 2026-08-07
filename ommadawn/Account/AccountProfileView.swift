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
import GoogleSignIn

struct AccountProfileView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var hasLoadedForm = false
    @State private var username = ""
    @State private var fullName = ""
    @State private var countryCode: String?
    @State private var showingCountryPicker = false
    @State private var city = ""
    @State private var includesBirthDate = false
    @State private var birthDate = Date.now

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var isSaving = false
    @State private var isLinkingGoogle = false
    @State private var showingUnlinkConfirmation = false
    @State private var showingChangePassword = false
    @State private var showingRemovePasswordConfirmation = false
    @State private var isRemovingPassword = false
    @State private var showingVerifyEmail = false
    @State private var errorMessage: String?
    /// Separado del `errorMessage` general: ese vive en su propia `Section`
    /// al final del formulario, demasiado lejos del botón de Google — un
    /// error ahí parece que el formulario entero falló, no que Google en
    /// concreto rechazó la acción. Este se pinta pegado a la sección.
    @State private var googleErrorMessage: String?
    /// Mismo motivo que `googleErrorMessage`, para "Quitar contraseña".
    @State private var passwordErrorMessage: String?

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
                        if user.username_is_default {
                            editableUsernameField
                        } else {
                            lockedField(label: "Usuario", value: user.username)
                        }
                        lockedField(label: "Email", value: user.email, showsGoogleMark: user.has_google)
                        if !user.email_verified {
                            emailVerificationRow
                        }
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

                Section("Seguridad") {
                    Button(user?.has_password == true ? "Cambiar contraseña" : "Agregar contraseña") {
                        showingChangePassword = true
                    }
                    if let user, user.has_password, user.has_google {
                        Button("Quitar contraseña", role: .destructive) {
                            showingRemovePasswordConfirmation = true
                        }
                        .disabled(isRemovingPassword)
                    }
                }
                .sheet(isPresented: $showingChangePassword) {
                    ChangePasswordView(hasPassword: user?.has_password ?? true)
                        .environment(session)
                }
                .confirmationDialog(
                    "¿Quitar la contraseña?",
                    isPresented: $showingRemovePasswordConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Quitar", role: .destructive) { Task { await removePassword() } }
                } message: {
                    Text("Solo podrás entrar con tu cuenta de Google. Podrás volver a ponerte una contraseña cuando quieras.")
                }
                .alert(
                    "Aviso",
                    isPresented: Binding(
                        get: { passwordErrorMessage != nil },
                        set: { if !$0 { passwordErrorMessage = nil } }
                    )
                ) {
                    Button("Vale", role: .cancel) {}
                } message: {
                    Text(passwordErrorMessage ?? "")
                }

                if let user {
                    googleAccountSection(for: user)
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
            .disabled(isSaving || isLinkingGoogle)
            .task {
                guard !hasLoadedForm, let user else { return }
                username = user.username
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

    // MARK: - Campos

    /// Nombre de usuario editable — solo aparece cuando la cuenta todavía
    /// tiene el username provisional que le puso el alta por Google
    /// (`username_is_default`). Es un cambio de un solo uso: en cuanto se
    /// guarda, el servidor lo fija para siempre y esta fila deja de salir.
    private var editableUsernameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent("Usuario") {
                TextField("", text: $username)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Text("Google te asignó este nombre. Puedes cambiarlo, pero solo una vez.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Fila de solo lectura, con un candado que la distingue a simple vista
    /// de los campos editables de al lado. Usuario y email no se pueden
    /// tocar desde aquí (no hay endpoint para cambiarlos en este formulario).
    ///
    /// - Parameter showsGoogleMark: si la cuenta tiene Google vinculado, se
    ///   añade la "G" junto al valor — de momento solo informativo, la
    ///   vinculación/desvinculación desde aquí llega en una tarea futura.
    private func lockedField(label: String, value: String, showsGoogleMark: Bool = false) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                if showsGoogleMark {
                    GoogleMark(size: 13)
                }
                Text(value)
                Image(systemName: "lock.fill")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.secondary)
    }

    /// Aviso "soft": el email sin verificar no bloquea nada de la app,
    /// solo se recuerda aquí con un botón para abrir `VerifyEmailView`.
    private var emailVerificationRow: some View {
        HStack {
            Label("Sin verificar", systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
            Spacer()
            Button("Verificar") {
                showingVerifyEmail = true
            }
            .font(.footnote)
        }
        .sheet(isPresented: $showingVerifyEmail) {
            VerifyEmailView()
                .environment(session)
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

    // MARK: - Cuenta de Google

    /// Vincular o desvincular Google. La API no expone si la cuenta tiene
    /// contraseña propia, así que "Desconectar Google" se muestra siempre
    /// que `has_google` sea `true` — si Google fuera la única forma de
    /// entrar, el servidor rechaza con `409` y el mensaje se lo explica a
    /// la persona en vez de adivinarlo de antemano.
    private func googleAccountSection(for user: User) -> some View {
        Section("Cuenta de Google") {
            if user.has_google {
                Button("Desconectar Google", role: .destructive) {
                    showingUnlinkConfirmation = true
                }
                .disabled(isLinkingGoogle)
            } else {
                Button {
                    Task { await linkGoogle() }
                } label: {
                    HStack(spacing: 8) {
                        if isLinkingGoogle {
                            ProgressView()
                        } else {
                            GoogleMark(size: 16)
                        }
                        Text("Conectar con Google")
                    }
                }
                .disabled(isLinkingGoogle)
            }
        }
        .confirmationDialog(
            "¿Desconectar Google?",
            isPresented: $showingUnlinkConfirmation,
            titleVisibility: .visible
        ) {
            Button("Desconectar", role: .destructive) { Task { await unlinkGoogle() } }
        } message: {
            Text("Ya no podrás entrar con tu cuenta de Google. Seguirás pudiendo entrar con tu usuario y contraseña.")
        }
        // Alert, no texto en la sección: si el botón queda fuera de la
        // pantalla visible al pulsarlo, un texto pegado a la sección puede
        // no llegar a verse sin hacer scroll. El alert sale centrado pase
        // lo que pase.
        .alert(
            "Aviso",
            isPresented: Binding(
                get: { googleErrorMessage != nil },
                set: { if !$0 { googleErrorMessage = nil } }
            )
        ) {
            Button("Vale", role: .cancel) {}
        } message: {
            Text(googleErrorMessage ?? "")
        }
    }

    private func linkGoogle() async {
        guard !isLinkingGoogle, let presenter = UIApplication.shared.topViewController else { return }
        googleErrorMessage = nil
        isLinkingGoogle = true
        defer { isLinkingGoogle = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                googleErrorMessage = "Google no devolvió un token válido. Inténtalo de nuevo."
                return
            }
            try await session.linkGoogleAccount(idToken: idToken)
        } catch let error as ProfileError {
            googleErrorMessage = message(for: error)
        } catch GIDSignInError.canceled {
            // Cancelado por el usuario: no es un error que mostrar.
        } catch {
            googleErrorMessage = "No se pudo conectar con Google. Inténtalo de nuevo."
        }
    }

    private func unlinkGoogle() async {
        googleErrorMessage = nil
        isLinkingGoogle = true
        defer { isLinkingGoogle = false }
        do {
            try await session.unlinkGoogleAccount()
        } catch let error as ProfileError {
            googleErrorMessage = message(for: error)
        } catch {
            googleErrorMessage = "No se pudo desconectar Google. Inténtalo de nuevo."
        }
    }

    private func removePassword() async {
        passwordErrorMessage = nil
        isRemovingPassword = true
        defer { isRemovingPassword = false }
        do {
            try await session.removePassword()
        } catch let error as PasswordChangeError {
            passwordErrorMessage = message(for: error)
        } catch {
            passwordErrorMessage = "No se pudo quitar la contraseña. Inténtalo de nuevo."
        }
    }

    private func message(for error: PasswordChangeError) -> String {
        switch error {
        case .wrongCurrentPassword:
            "La contraseña actual no es correcta."
        case .sessionExpired:
            "Tu sesión ha caducado. Vuelve a iniciar sesión."
        case .invalidData:
            "Revisa la nueva contraseña."
        case .passwordOnlyAccess:
            "Tu cuenta no tiene Google vinculado: la contraseña es tu única forma de entrar."
        case .unexpected(let statusCode):
            "Error del servidor (\(statusCode)). Inténtalo más tarde."
        case .network:
            "No se pudo conectar. Comprueba tu conexión."
        }
    }

    // MARK: - Perfil

    private func saveProfile() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        // Solo se manda si de verdad se ha tocado: mandarlo sin cambios
        // gastaría igualmente el único cambio permitido en el servidor.
        let usernameToSend = (user?.username_is_default == true && !trimmedUsername.isEmpty && trimmedUsername != user?.username)
            ? trimmedUsername : nil

        do {
            try await session.updateProfile(
                username: usernameToSend,
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
        case .usernameTaken:
            "Ese nombre de usuario ya está en uso. Prueba con otro."
        case .usernameLocked:
            "Ya has elegido tu nombre de usuario definitivo."
        case .googleAlreadyLinked:
            "Esa cuenta de Google ya está vinculada a otro usuario."
        case .googleOnlyAccess:
            "Google es tu única forma de entrar. Para desvincularlo, primero pon una contraseña."
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
            username: "user-4821",
            username_is_default: true,
            email: "rafa@example.com",
            email_verified: true,
            full_name: "Rafa García",
            theme_preference: .system,
            has_google: true,
            has_password: false,
            is_active: true,
            is_admin: false,
            is_super_admin: false,
            created_at: .now
        ))))
}

#Preview("Email sin verificar") {
    AccountProfileView()
        .environment(AuthSession(initialState: .signedIn(User(
            id: 1,
            username: "rafatest",
            username_is_default: false,
            email: "rafa@example.com",
            email_verified: false,
            full_name: "Rafa García",
            theme_preference: .system,
            has_google: false,
            has_password: true,
            is_active: true,
            is_admin: false,
            is_super_admin: false,
            created_at: .now
        ))))
}
