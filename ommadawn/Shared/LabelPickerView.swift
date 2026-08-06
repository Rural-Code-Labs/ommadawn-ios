//
//  LabelPickerView.swift
//  ommadawn
//
//  Hoja de selección de sello discográfico.
//  Lista buscable ordenada por número de ediciones (desc). Permite crear uno
//  nuevo si no existe, y eliminar los que tienen 0 ediciones.
//

import SwiftUI
import OmmadawnAPI

struct LabelPickerView: View {
    @Binding var selectedLabel: RecordLabel?
    let store: DiscographyStore

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [RecordLabel] = []
    @State private var isLoading = false
    @State private var isCreating = false
    @State private var deletingID: Int?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if !query.isEmpty {
                    Section {
                        Button {
                            Task { await createLabel(name: query.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        } label: {
                            SwiftUI.Label("Crear \"\(query.trimmingCharacters(in: .whitespacesAndNewlines))\"", systemImage: "plus.circle")
                        }
                        .disabled(isCreating || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if results.isEmpty && !isLoading {
                    Section {
                        Text(query.isEmpty ? "No hay sellos" : "Sin resultados")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(results, id: \.id) { label in
                            HStack {
                                Button {
                                    selectedLabel = label
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(label.name)
                                            Text("\(label.edition_count ?? 0) ediciones")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedLabel?.id == label.id {
                                            Image(systemName: "checkmark").foregroundStyle(.tint)
                                        }
                                    }
                                }
                                .foregroundStyle(.primary)

                                if (label.edition_count ?? 0) == 0 {
                                    Button(role: .destructive) {
                                        Task { await deleteLabel(label) }
                                    } label: {
                                        if deletingID == label.id {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Sello discográfico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                if selectedLabel != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Quitar sello", role: .destructive) {
                            selectedLabel = nil
                            dismiss()
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar sello…")
            .onChange(of: query) { _, _ in
                Task { await search() }
            }
            .task { await search() }
            .overlay {
                if isLoading { ProgressView() }
            }
        }
    }

    private func search() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await store.fetchLabels(q: query)
        } catch {
            errorMessage = "Error al cargar sellos"
        }
    }

    private func createLabel(name: String) async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            let created = try await store.createLabel(name: name)
            selectedLabel = created
            dismiss()
        } catch DiscographyError.unexpected(409) {
            // Ya existe con ese nombre — buscarlo y seleccionarlo
            await search()
            if let existing = results.first(where: { $0.name.lowercased() == name.lowercased() }) {
                selectedLabel = existing
                dismiss()
            } else {
                errorMessage = "Ya existe un sello con ese nombre"
            }
        } catch {
            errorMessage = "Error al crear el sello"
        }
    }

    private func deleteLabel(_ label: RecordLabel) async {
        deletingID = label.id
        errorMessage = nil
        defer { deletingID = nil }
        do {
            let deleted = try await store.deleteLabel(id: label.id)
            if deleted {
                results.removeAll { $0.id == label.id }
                if selectedLabel?.id == label.id { selectedLabel = nil }
            } else {
                errorMessage = "El sello tiene ediciones asociadas"
            }
        } catch DiscographyError.forbidden {
            errorMessage = "Sin permisos para eliminar"
        } catch {
            errorMessage = "Error al eliminar el sello"
        }
    }
}
