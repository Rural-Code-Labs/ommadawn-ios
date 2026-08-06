//
//  GoogleMark.swift
//  ommadawn
//
//  La "G" de Google en degradado con sus cuatro colores de marca — un guiño
//  a la paleta, no una copia del logotipo real. Se usa tanto en el botón de
//  LoginView como junto al email en el perfil, cuando la cuenta tiene Google
//  vinculado.
//

import SwiftUI

struct GoogleMark: View {
    var size: CGFloat = 20

    var body: some View {
        Text("G")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(
                AngularGradient(colors: [.red, .yellow, .green, .blue, .red], center: .center)
            )
    }
}

#Preview {
    GoogleMark()
}
