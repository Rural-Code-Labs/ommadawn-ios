//
//  SubforumListView.swift
//  ommadawn
//
//  "Ver todo" de la actividad del foro (Inicio): lista los subforos y, al
//  entrar en uno, todos sus hilos (ForumThreadListView sin filtro de
//  entidad). Se presenta como hoja — necesita su propio NavigationStack.
//
//  Gestión de subforos para admins (Fase 7.6): crear, editar, reordenar
//  (↑↓, mismo patrón que las imágenes de una edición) y borrar (solo si no
//  tiene hilos).
//

import SwiftUI
import OmmadawnAPI

struct SubforumListView: View {
    let store: ForumStore

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var session

    @State private var subforums: [SubforumSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingCreate = false
    @State private var editingSubforum: SubforumSummary?
    @State private var deleteCandidate: SubforumSummary?
    @State private var deleteErrorMessage: String?
    @State private var movingId: Int?

    private var isAdmin: Bool {
        guard case .signedIn(let user) = session.state else { return false }
        return user.is_admin
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Subforos")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                    if isAdmin {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showingCreate = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                .task { await load() }
                .sheet(isPresented: $showingCreate) {
                    SubforumFormView(store: store, onCreated: { created in
                        subforums.append(created)
                    })
                }
                .sheet(item: $editingSubforum) { subforum in
                    SubforumFormView(store: store, existing: subforum) { updated in
                        if let index = subforums.firstIndex(where: { $0.id == updated.id }) {
                            subforums[index] = updated
                        }
                    }
                }
                .confirmationDialog(
                    "¿Eliminar «\(deleteCandidate?.name ?? "")»?",
                    isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("Eliminar", role: .destructive) {
                        if let deleteCandidate { Task { await delete(deleteCandidate) } }
                    }
                }
                .alert("No se pudo eliminar", isPresented: Binding(
                    get: { deleteErrorMessage != nil },
                    set: { if !$0 { deleteErrorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(deleteErrorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && subforums.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.slash")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Reintentar") { Task { await load() } }
            }
        } else if subforums.isEmpty {
            ContentUnavailableView(
                "Sin subforos todavía",
                systemImage: "square.stack",
                description: Text("Todavía no hay ninguna sección del foro creada.")
            )
        } else {
            List {
                ForEach(Array(subforums.enumerated()), id: \.element.id) { index, subforum in
                    HStack {
                        NavigationLink {
                            ForumThreadListView(
                                store: store,
                                subforumId: subforum.id,
                                navigationTitle: subforum.name,
                                showsCloseButton: false
                            )
                        } label: {
                            SubforumRow(subforum: subforum)
                        }
                        if isAdmin {
                            adminMenu(for: subforum, isFirst: index == 0, isLast: index == subforums.count - 1)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
    }

    private func adminMenu(for subforum: SubforumSummary, isFirst: Bool, isLast: Bool) -> some View {
        Menu {
            Button {
                editingSubforum = subforum
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            Button {
                Task { await move(subforum, .up) }
            } label: {
                Label("Subir", systemImage: "chevron.up")
            }
            .disabled(isFirst)
            Button {
                Task { await move(subforum, .down) }
            } label: {
                Label("Bajar", systemImage: "chevron.down")
            }
            .disabled(isLast)
            Button(role: .destructive) {
                deleteCandidate = subforum
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
            .disabled(subforum.thread_count > 0)
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .disabled(movingId != nil)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            subforums = try await store.fetchSubforums()
        } catch {
            errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
        }
    }

    private func move(_ subforum: SubforumSummary, _ direction: Components.Schemas.SubforumMoveRequest.directionPayload) async {
        movingId = subforum.id
        defer { movingId = nil }
        do {
            subforums = try await store.moveSubforum(id: subforum.id, direction: direction)
        } catch {
            // Sin aviso aparte: si falla, el orden simplemente no cambia y se puede reintentar.
        }
    }

    private func delete(_ subforum: SubforumSummary) async {
        do {
            try await store.deleteSubforum(id: subforum.id)
            subforums.removeAll { $0.id == subforum.id }
        } catch ForumError.subforumHasThreads {
            deleteErrorMessage = "No se puede eliminar: todavía tiene hilos."
        } catch {
            deleteErrorMessage = "Inténtalo de nuevo."
        }
    }
}

private struct SubforumRow: View {
    let subforum: SubforumSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: subforum.icon ?? "bubble.left.and.bubble.right")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(subforum.name)
                    .font(.body)
                if let description = subforum.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Crear o editar un subforo (`existing` distingue). Solo admins llegan aquí.
struct SubforumFormView: View {
    let store: ForumStore
    var existing: SubforumSummary? = nil
    var onCreated: ((SubforumSummary) -> Void)? = nil
    var onUpdated: ((SubforumSummary) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var adminOnly: Bool
    @State private var showingIconPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        store: ForumStore,
        existing: SubforumSummary? = nil,
        onCreated: ((SubforumSummary) -> Void)? = nil,
        onUpdated: ((SubforumSummary) -> Void)? = nil
    ) {
        self.store = store
        self.existing = existing
        self.onCreated = onCreated
        self.onUpdated = onUpdated
        _name = State(initialValue: existing?.name ?? "")
        _description = State(initialValue: existing?.description ?? "")
        _icon = State(initialValue: existing?.icon ?? "")
        _adminOnly = State(initialValue: existing?.admin_only ?? false)
    }

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)
                    TextField("Descripción (opcional)", text: $description, axis: .vertical)
                    Button {
                        showingIconPicker = true
                    } label: {
                        LabeledContent("Icono") {
                            if icon.isEmpty {
                                Text("Ninguno").foregroundStyle(.secondary)
                            } else {
                                Image(systemName: icon).foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Section {
                    Toggle("Solo administradores pueden abrir hilos", isOn: $adminOnly)
                } footer: {
                    Text("Cualquiera con email verificado puede leer y comentar, sea cual sea esta opción.")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar subforo" : "Nuevo subforo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Guardar" : "Crear") { Task { await save() } }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .disabled(isSaving)
            .sheet(isPresented: $showingIconPicker) {
                SFSymbolPickerView(selection: $icon)
            }
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let existing {
                let updated = try await store.updateSubforum(
                    id: existing.id,
                    name: trimmedName,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    icon: trimmedIcon.isEmpty ? nil : trimmedIcon,
                    adminOnly: adminOnly
                )
                onUpdated?(updated)
            } else {
                let created = try await store.createSubforum(
                    name: trimmedName,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    icon: trimmedIcon.isEmpty ? nil : trimmedIcon,
                    adminOnly: adminOnly
                )
                onCreated?(created)
            }
            dismiss()
        } catch ForumError.nameTaken {
            errorMessage = "Ya existe un subforo con ese nombre."
        } catch {
            errorMessage = isEditing ? "No se pudo guardar. Inténtalo de nuevo." : "No se pudo crear el subforo. Inténtalo de nuevo."
        }
    }
}
