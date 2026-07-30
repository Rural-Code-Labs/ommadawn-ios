//
//  Models.swift
//  OmmadawnAPI
//
//  Alias de conveniencia sobre los tipos generados, para que la app use
//  nombres cómodos en vez de `Components.Schemas.*`.
//

import Foundation

/// Usuario autenticado (respuesta de `GET /auth/me` y `POST /auth/register`).
public typealias User = Components.Schemas.UserRead

/// Una obra del catálogo (disco, recopilatorio, single, bootleg...), con sus ediciones.
public typealias Release = Components.Schemas.ReleaseRead
/// Tipo de obra: `.studio`, `.compilation`, `.single`, `.bootleg`.
public typealias ReleaseType = Components.Schemas.ReleaseType
/// Una publicación concreta de una `Release` (país, sello, fecha), con su tracklist.
public typealias Edition = Components.Schemas.EditionRead
/// Un tema de la tracklist de una `Edition`.
public typealias Track = Components.Schemas.TrackRead
/// Una imagen (portada, contraportada...) de una `Edition`.
///
/// No se llama `Image` a secas: colisionaría con `SwiftUI.Image` en cualquier
/// vista que importe ambos módulos.
public typealias ReleaseImage = Components.Schemas.ImageRead
/// Tipo de `ReleaseImage`: `.front_cover`, `.back_cover`, `.other`.
public typealias ReleaseImageType = Components.Schemas.ImageType
/// Formato de una `Edition`: `.vinyl`, `.cd`, `.single`, `.maxi_single`, `.cd_single`, `.cassette`.
public typealias EditionFormat = Components.Schemas.EditionFormat

/// El generador ya le da `id: Int`; declararlo aquí (dentro del propio
/// paquete, no en el target de la app) evita el warning de conformidad
/// retroactiva y permite usar los temas directamente en un `ForEach`.
extension Track: Identifiable {}
