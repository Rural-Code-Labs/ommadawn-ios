//
//  AboutView.swift
//  ommadawn
//
//  Panel "Acerca de": quién hace la app, versión, etc. Se abre desde el
//  icono de información en el login y, más adelante, desde un botón propio
//  en el menú de Cuenta — por eso vive en Design/ como componente
//  reutilizable, no dentro de Auth/ ni Account/.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("""
                    Ommadawn nació como un proyecto personal de Rural Code Labs: \
                    catalogar con cariño el universo de Mike Oldfield, registrando \
                    cada edición de sus discos, sus conciertos y mucho más.
                    """)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 16)

                    VStack(spacing: 8) {
                        Image("RuralCodeLabsLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 72)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                        Text("Rural Code Labs")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 4) {
                        Text("Versión Beta (Opus One)")
                        Text("Rafael García Álvarez — Rural Code Labs")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Acerca de")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AboutView()
}
