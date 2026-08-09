//
//  ChangelogEntry.swift
//  ommadawn
//
//  Contenido de ejemplo: no hay backend de changelog todavía (pendiente de
//  un campo `updated_at` en Release/Edition que la API no tiene aún — ver
//  CLAUDE.md, Fase 7.5). Se sustituye por datos reales el día que exista.
//

import Foundation

struct ChangelogEntry: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let detail: String
}

let sampleChangelog: [ChangelogEntry] = [
    ChangelogEntry(
        title: "Tubular Bells 2003",
        date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
        detail: "Se añadieron créditos completos a la tracklist."
    ),
    ChangelogEntry(
        title: "Hergest Ridge",
        date: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now,
        detail: "Nueva edición: LP japonés (1976)."
    ),
    ChangelogEntry(
        title: "Amarok",
        date: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
        detail: "Corregida la fecha de publicación de la edición original."
    ),
    ChangelogEntry(
        title: "The Orchestral Tubular Bells",
        date: Calendar.current.date(byAdding: .day, value: -5, to: .now) ?? .now,
        detail: "Se añadió la portada y contraportada."
    ),
    ChangelogEntry(
        title: "Remasterizaciones HDCD",
        date: Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now,
        detail: "Nueva colección de ediciones."
    ),
    ChangelogEntry(
        title: "Ommadawn",
        date: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
        detail: "Notas ampliadas sobre la grabación del disco."
    ),
]
