//
//  AccountAvatarView.swift
//  ommadawn
//
//  Icono de cuenta: la foto de perfil en un círculo si el usuario tiene
//  avatar, si no el símbolo genérico de persona. Se usa tanto en el icono
//  pequeño de la cabecera (AccountMenu) como en el preview grande de
//  AccountProfileView.
//

import SwiftUI
import OmmadawnAPI

struct AccountAvatarView: View {
    let user: User
    var size: CGFloat = 28

    var body: some View {
        if let url = user.avatarURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                placeholder
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            placeholder
                .frame(width: size, height: size)
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle")
            .font(.system(size: size))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    AccountAvatarView(user: User(
        id: 1,
        username: "rafatest",
        email: "rafa@example.com",
        theme_preference: .system,
        is_active: true,
        is_admin: false,
        is_super_admin: false,
        created_at: .now
    ), size: 80)
}
