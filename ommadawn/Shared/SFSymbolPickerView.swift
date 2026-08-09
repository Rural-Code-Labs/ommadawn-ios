//
//  SFSymbolPickerView.swift
//  ommadawn
//
//  Selector visual de icono (SF Symbol) con buscador, para no depender de
//  escribir el nombre exacto a mano. Lista curada, no el catálogo completo
//  de SF Symbols (no hay forma de enumerarlo sin la app SF Symbols).
//

import SwiftUI

struct SFSymbolPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 12)]

    private var filtered: [String] {
        guard !query.isEmpty else { return Self.symbols }
        return Self.symbols.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filtered, id: \.self) { symbol in
                            Button {
                                selection = symbol
                                dismiss()
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title2)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        symbol == selection ? Color.accentColor.opacity(0.2) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .searchable(text: $query, prompt: "Buscar icono")
            .navigationTitle("Elegir icono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                if !selection.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Quitar") {
                            selection = ""
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private static let symbols: [String] = [
        "bubble.left.and.bubble.right", "bubble.left", "bubble.right",
        "megaphone", "star", "star.fill", "flag", "flag.fill",
        "pin", "pin.fill", "tag", "tag.fill", "bell", "bell.fill",
        "exclamationmark.bubble", "questionmark.bubble", "questionmark.circle",
        "info.circle", "lightbulb", "heart", "heart.fill",
        "hand.thumbsup", "hand.thumbsup.fill", "checkmark.circle", "checkmark.seal",
        "person", "person.2", "person.3", "globe", "house", "map",
        "calendar", "clock", "gearshape", "wrench.and.screwdriver", "hammer",
        "shield", "lock", "key", "eye", "envelope", "paperplane",
        "tray", "doc.text", "note.text", "pencil", "folder", "archivebox",
        "book", "books.vertical", "music.note", "guitars", "headphones", "mic",
        "camera", "photo", "video", "film", "gamecontroller",
        "sportscourt", "trophy", "flame", "bolt", "cloud",
        "sun.max", "moon.stars", "leaf", "sparkles", "party.popper",
        "gift", "cart", "creditcard", "briefcase", "graduationcap",
        "building", "car", "airplane", "opticaldisc", "waveform",
    ]
}
