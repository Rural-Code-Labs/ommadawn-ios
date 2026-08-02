//
//  CountryPickerView.swift
//  ommadawn
//
//  Selector de país reutilizable: sección de frecuentes, buscador siempre
//  visible y lista completa ISO 3166-1 con bandera y nombre en español.
//

import SwiftUI

struct CountryPickerView: View {
    @Binding var selectedCode: String?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    // Países más habituales en discografías internacionales (en orden de
    // aparición deseada en la sección de frecuentes).
    private static let frequentCodes = [
        "GB", "DE", "US", "JP", "NL", "FR", "IT", "AU", "CA", "ES"
    ]

    private var frequentCountries: [Country] {
        Self.frequentCodes.compactMap { Country.find($0) }
    }

    private var filtered: [Country] {
        let q = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Country.all }
        return Country.all.filter {
            $0.name.lowercased().contains(q) || $0.code.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Buscador siempre visible en la cabecera de la lista.
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Buscar país", text: $searchText)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if selectedCode != nil, searchText.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            selectedCode = nil
                            dismiss()
                        } label: {
                            Label("Quitar país", systemImage: "xmark.circle")
                        }
                    }
                }

                if searchText.isEmpty {
                    Section("Frecuentes") {
                        ForEach(frequentCountries) { country in
                            countryRow(country)
                        }
                    }
                    Section("Todos") {
                        ForEach(Country.all) { country in
                            countryRow(country)
                        }
                    }
                } else {
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        Section {
                            ForEach(filtered) { country in
                                countryRow(country)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("País")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func countryRow(_ country: Country) -> some View {
        Button {
            selectedCode = country.code
            dismiss()
        } label: {
            HStack {
                Text(country.flag)
                    .font(.title3)
                    .frame(width: 32)
                Text(country.name)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedCode == country.code {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
