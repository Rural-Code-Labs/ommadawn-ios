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
        // "O" de Didot (alto contraste) inclinada, como una O caligráfica.
        Text("O")
            .font(.custom("Didot-Bold", size: size))
            .rotationEffect(.degrees(18))
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
