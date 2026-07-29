//
//  BrandMark.swift
//  ommadawn
//
//  La marca de la app: la inicial "O" en gris (SF Rounded), a juego con el
//  icono. Es una vista reutilizable para no repetir el logo por ahí.
//

import SwiftUI

struct BrandMark: View {
    /// Tamaño de la letra en puntos.
    var size: CGFloat = 64

    var body: some View {
        // "O" de Didot Italic — misma familia y estilo que el wordmark
        // "Ommadawn" (Didot-Italic), para que logo y título compartan letra.
        Text("O")
            .font(.custom("Didot-Italic", size: size))
            .foregroundStyle(Color("BrandGray"))
            .accessibilityHidden(true) // decorativa; el nombre lo da el texto
    }
}

#Preview {
    VStack(spacing: 24) {
        BrandMark()
        BrandMark(size: 120)
    }
    .padding()
}
