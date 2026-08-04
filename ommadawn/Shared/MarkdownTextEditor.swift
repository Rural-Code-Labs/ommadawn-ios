//
//  MarkdownTextEditor.swift
//  ommadawn
//
//  UITextView envuelto para SwiftUI con un controlador que permite insertar
//  y envolver texto con sintaxis Markdown desde botones externos a la vista.
//
//  Uso habitual:
//    MarkdownEditorSection("Descripción", text: $desc, controller: ctrl) {
//        showingCheatsheet = true
//    }
//

import SwiftUI
import UIKit

// MARK: - Controlador

/// Mantiene una referencia débil al UITextView activo y expone acciones de
/// inserción de sintaxis Markdown. Se declara con @State en la vista padre
/// para que sobreviva a los re-renders de SwiftUI.
@Observable @MainActor
final class MarkdownEditorController {
    weak var textView: UITextView?

    /// Envuelve el texto seleccionado (o inserta marcadores vacíos con el cursor
    /// entre ellos si no hay selección) con el marcador dado.
    func wrapSelection(with marker: String) {
        guard let tv = textView, let range = tv.selectedTextRange else { return }
        let selected = tv.text(in: range) ?? ""
        if selected.isEmpty {
            tv.replace(range, withText: "\(marker)\(marker)")
            if let pos = tv.selectedTextRange?.start,
               let back = tv.position(from: pos, offset: -marker.count) {
                tv.selectedTextRange = tv.textRange(from: back, to: back)
            }
        } else {
            tv.replace(range, withText: "\(marker)\(selected)\(marker)")
        }
    }

    /// Inserta sintaxis de enlace. Si hay texto seleccionado lo usa como etiqueta.
    func insertLink() {
        guard let tv = textView, let range = tv.selectedTextRange else { return }
        let selected = tv.text(in: range) ?? ""
        let insertion = selected.isEmpty ? "[texto](url)" : "[\(selected)](url)"
        tv.replace(range, withText: insertion)
    }

    /// Inserta un elemento de lista con viñeta en la posición actual.
    func insertListItem() {
        guard let tv = textView, let range = tv.selectedTextRange else { return }
        tv.replace(range, withText: "- ")
    }

    /// Inserta un bloque de cita en la posición actual.
    func insertBlockquote() {
        guard let tv = textView, let range = tv.selectedTextRange else { return }
        let selected = tv.text(in: range) ?? ""
        let insertion = selected.isEmpty ? "> " : selected.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }.joined(separator: "\n")
        tv.replace(range, withText: insertion)
    }
}

// MARK: - UITextView envuelto

struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    let controller: MarkdownEditorController

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .preferredFont(forTextStyle: .body)
        tv.textColor = .label
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        controller.textView = tv
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        controller.textView = uiView
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }
}

// MARK: - Sección reutilizable para formularios

/// Section de SwiftUI lista para usar dentro de un Form. Incluye la toolbar
/// de Markdown y el editor de texto en una sola pieza composable.
struct MarkdownEditorSection: View {
    private let title: String
    @Binding var text: String
    let controller: MarkdownEditorController
    var editorHeight: CGFloat = 180
    let onCheatsheet: () -> Void

    init(_ title: String, text: Binding<String>, controller: MarkdownEditorController,
         editorHeight: CGFloat = 180, onCheatsheet: @escaping () -> Void) {
        self.title = title
        self._text = text
        self.controller = controller
        self.editorHeight = editorHeight
        self.onCheatsheet = onCheatsheet
    }

    var body: some View {
        Section {
            toolbar
            MarkdownTextEditor(text: $text, controller: controller)
                .frame(height: editorHeight)
        } header: {
            Text(title)
        } footer: {
            Text("Admite Markdown: **negrita**, _cursiva_, [enlace](url).")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            toolbarButton(action: { controller.wrapSelection(with: "**") }) {
                Text("N").bold()
            }
            toolbarButton(action: { controller.wrapSelection(with: "_") }) {
                Text("C").italic()
            }
            toolbarButton(action: { controller.insertLink() }) {
                Image(systemName: "link")
            }
            toolbarButton(action: { controller.insertListItem() }) {
                Image(systemName: "list.bullet")
            }
            toolbarButton(action: { controller.insertBlockquote() }) {
                Image(systemName: "text.quote")
            }

            Spacer()

            Button(action: onCheatsheet) {
                Image(systemName: "questionmark.circle")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func toolbarButton<L: View>(action: @escaping () -> Void, @ViewBuilder label: () -> L) -> some View {
        Button(action: action) {
            label().frame(width: 32, height: 32)
        }
        .buttonStyle(.borderless)
    }
}
