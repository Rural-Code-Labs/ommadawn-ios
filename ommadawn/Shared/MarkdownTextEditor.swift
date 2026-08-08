//
//  MarkdownTextEditor.swift
//  ommadawn
//
//  UITextView envuelto para SwiftUI con un controlador que permite insertar
//  y envolver texto con sintaxis Markdown desde botones externos a la vista.
//  Incluye también el renderizador Markdown → HTML (WKWebView) compartido
//  por el editor (botón ojo) y la vista de detalle (hoja "Leer más").
//
//  Uso habitual:
//    MarkdownEditorSection("Descripción", text: $desc, controller: ctrl) {
//        showingCheatsheet = true
//    }
//

import SwiftUI
import UIKit
import WebKit

// MARK: - Controlador

/// Mantiene una referencia débil al UITextView activo y expone acciones de
/// inserción de sintaxis Markdown. Se declara con @State en la vista padre
/// para que sobreviva a los re-renders de SwiftUI.
@Observable @MainActor
final class MarkdownEditorController {
    weak var textView: UITextView?
    var showingPreview = false
    var previewTitle: String = ""
    var previewText: String = ""

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

            toolbarButton(action: {
                controller.previewTitle = title
                controller.previewText = text
                controller.showingPreview = true
            }) {
                Image(systemName: "eye")
            }
            .foregroundStyle(.secondary)

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

// MARK: - Hoja de preview Markdown (compartida con ReleaseDetailView)

struct MarkdownPreviewSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MarkdownWebView(text: text)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
    }
}

// MARK: - WKWebView con altura dinámica (para incrustar en ScrollView)

struct DynamicMarkdownWebView: UIViewRepresentable {
    let text: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(contentHeight: $contentHeight) }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.navigationDelegate = context.coordinator
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(markdownInlineHTML(text), baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var contentHeight: CGFloat
        init(contentHeight: Binding<CGFloat>) { _contentHeight = contentHeight }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                DispatchQueue.main.async {
                    if let h = result as? CGFloat        { self.contentHeight = h }
                    else if let h = result as? Double    { self.contentHeight = CGFloat(h) }
                    else if let h = result as? Int       { self.contentHeight = CGFloat(h) }
                }
            }
        }
    }
}

/// Bloque de Markdown renderizado, siempre expandido (a diferencia de
/// `CollapsibleMarkdownSection` en `ReleaseDetailView`, que se pliega tras un
/// chevron) — para el cuerpo de un hilo del foro o un comentario, donde el
/// texto ES el contenido principal, no un extra opcional.
struct MarkdownBlock: View {
    let text: String
    @State private var height: CGFloat = 44

    var body: some View {
        DynamicMarkdownWebView(text: text, contentHeight: $height)
            .frame(height: height)
    }
}

// MARK: - WKWebView para Markdown

struct MarkdownWebView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(markdownStyledHTML(text), baseURL: nil)
    }
}

// MARK: - Conversor Markdown → HTML

func markdownStyledHTML(_ markdown: String) -> String {
    """
    <!DOCTYPE html><html><head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <style>
    :root { color-scheme: light dark; }
    body {
        font-family: -apple-system, sans-serif; font-size: 17px;
        color: #000; background: transparent;
        margin: 0; padding: 16px; line-height: 1.6;
        -webkit-text-size-adjust: 100%;
    }
    @media (prefers-color-scheme: dark) { body { color: #fff; } }
    h1 { font-size: 26px; font-weight: 700; margin: 4px 0 10px; }
    h2 { font-size: 20px; font-weight: 700; margin: 18px 0 8px; }
    h3 { font-size: 17px; font-weight: 600; margin: 14px 0 6px; }
    p  { margin: 0 0 10px; }
    ul, ol { padding-left: 20px; margin: 0 0 10px; }
    li { margin-bottom: 4px; }
    blockquote { border-left: 3px solid rgba(128,128,128,0.5); margin: 0 0 10px; padding: 2px 12px; opacity: 0.8; }
    code { font-family: monospace; font-size: 14px; background: rgba(128,128,128,0.15); padding: 1px 4px; border-radius: 3px; }
    strong { font-weight: 700; }
    em { font-style: italic; }
    a { color: #007AFF; }
    hr { border: none; border-top: 1px solid rgba(128,128,128,0.3); margin: 14px 0; }
    </style></head>
    <body>\(markdownToHTML(markdown))</body></html>
    """
}

func markdownInlineHTML(_ markdown: String) -> String {
    """
    <!DOCTYPE html><html><head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <style>
    :root { color-scheme: light dark; }
    body {
        font-family: -apple-system, sans-serif; font-size: 17px;
        color: #000; background: transparent;
        margin: 0; padding: 0; line-height: 1.6;
        -webkit-text-size-adjust: 100%;
    }
    @media (prefers-color-scheme: dark) { body { color: #fff; } }
    h1 { font-size: 22px; font-weight: 700; margin: 0 0 8px; }
    h2 { font-size: 18px; font-weight: 700; margin: 14px 0 6px; }
    h3 { font-size: 16px; font-weight: 600; margin: 10px 0 4px; }
    p  { margin: 0 0 8px; }
    ul, ol { padding-left: 20px; margin: 0 0 8px; }
    li { margin-bottom: 3px; }
    blockquote { border-left: 3px solid rgba(128,128,128,0.5); margin: 0 0 8px; padding: 2px 10px; opacity: 0.8; }
    code { font-family: monospace; font-size: 14px; background: rgba(128,128,128,0.15); padding: 1px 4px; border-radius: 3px; }
    strong { font-weight: 700; }
    em { font-style: italic; }
    a { color: #007AFF; }
    hr { border: none; border-top: 1px solid rgba(128,128,128,0.3); margin: 10px 0; }
    </style></head>
    <body>\(markdownToHTML(markdown))</body></html>
    """
}

func markdownToHTML(_ text: String) -> String {
    var html = ""
    let lines = text.components(separatedBy: "\n")
    var inParagraph = false
    var inUL = false
    var inOL = false
    var inBlockquote = false

    func closeParagraph()  { if inParagraph  { html += "</p>";          inParagraph  = false } }
    func closeUL()         { if inUL         { html += "</ul>";         inUL         = false } }
    func closeOL()         { if inOL         { html += "</ol>";         inOL         = false } }
    func closeBlockquote() { if inBlockquote { html += "</blockquote>"; inBlockquote = false } }
    func closeAll() { closeParagraph(); closeUL(); closeOL(); closeBlockquote() }

    for line in lines {
        if line.hasPrefix("### ") {
            closeAll()
            html += "<h3>\(inlineMd(String(line.dropFirst(4))))</h3>"
        } else if line.hasPrefix("## ") {
            closeAll()
            html += "<h2>\(inlineMd(String(line.dropFirst(3))))</h2>"
        } else if line.hasPrefix("# ") {
            closeAll()
            html += "<h1>\(inlineMd(String(line.dropFirst(2))))</h1>"
        } else if line == "---" || line == "***" || line == "___" {
            closeAll()
            html += "<hr>"
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            closeParagraph(); closeOL(); closeBlockquote()
            if !inUL { html += "<ul>"; inUL = true }
            html += "<li>\(inlineMd(String(line.dropFirst(2))))</li>"
        } else if let r = line.range(of: #"^\d+\. "#, options: .regularExpression) {
            closeParagraph(); closeUL(); closeBlockquote()
            if !inOL { html += "<ol>"; inOL = true }
            html += "<li>\(inlineMd(String(line[r.upperBound...])))</li>"
        } else if line.hasPrefix("> ") {
            closeParagraph(); closeUL(); closeOL()
            if !inBlockquote { html += "<blockquote>"; inBlockquote = true } else { html += "<br>" }
            html += inlineMd(String(line.dropFirst(2)))
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            closeAll()
        } else {
            closeUL(); closeOL(); closeBlockquote()
            if !inParagraph { html += "<p>"; inParagraph = true } else { html += "<br>" }
            html += inlineMd(line)
        }
    }
    closeAll()
    return html
}

func inlineMd(_ raw: String) -> String {
    var s = raw
    s = s.replacingOccurrences(of: "&", with: "&amp;")
    s = s.replacingOccurrences(of: "<", with: "&lt;")
    s = s.replacingOccurrences(of: ">", with: "&gt;")
    s = s.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"__(.+?)__"#,     with: "<strong>$1</strong>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"(?<![*])\*([^*\n]+?)\*(?![*])"#, with: "<em>$1</em>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"(?<!_)_([^_\n]+?)_(?!_)"#,       with: "<em>$1</em>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"`([^`]+)`"#,                      with: "<code>$1</code>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#,        with: "<a href=\"$2\">$1</a>", options: .regularExpression)
    return s
}
