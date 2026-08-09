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
/// Sello discográfico de una `Edition`.
/// No se llama `Label` a secas: colisionaría con `SwiftUI.Label` en las vistas.
public typealias RecordLabel = Components.Schemas.LabelRead

/// Una colección de ediciones (ej. "Remasterizaciones HDCD"), tal como
/// aparece en el listado — con portadas de muestra, sin el detalle completo.
public typealias CollectionSummary = Components.Schemas.CollectionListRead
/// El detalle de una colección: sus ediciones, ordenadas por fecha de
/// publicación (nunca a mano — ver `CollectionEdition`).
public typealias CollectionDetail = Components.Schemas.CollectionDetailRead
/// Una edición dentro de una colección, con los datos de su obra de origen
/// (`release_id`/`release_title`/`release_type`) porque aquí, a diferencia
/// de `Edition` anidada bajo su `Release`, el disco de origen no es implícito.
public typealias CollectionEdition = Components.Schemas.CollectionEditionRead
/// Vista mínima (`id` + `name`) de una colección, colgada de
/// `Edition.collections` — qué colecciones incluyen esta edición.
public typealias CollectionTag = Components.Schemas.CollectionSummaryRead

/// Una sección del foro (ej. "Discusiones"). Todo hilo vive dentro de un
/// subforo; hoy solo existe uno, pero el modelo ya soporta más en el futuro.
public typealias SubforumSummary = Components.Schemas.SubforumRead
/// A qué se refiere un hilo del foro: `.release`, `.edition`, `.discography`
/// (tema general, sin disco concreto). `nil` en `ForumThreadDetail.entity_type`
/// es un caso más — "sin tema en absoluto" — que este enum no cubre a
/// propósito (ver `ForumThreadCreate` en el paquete de la API).
public typealias ForumEntityType = Components.Schemas.ForumEntityType
/// Estado de un hilo: `.open`, `.resolved`, `.closed`.
public typealias ForumThreadStatus = Components.Schemas.ThreadStatus
/// Un hilo del foro tal como aparece en el listado — sin cuerpo ni comentarios.
public typealias ForumThreadSummary = Components.Schemas.ThreadListRead
/// Página de resultados de `GET /forum/threads`: `items` + `total` (el
/// número de hilos que cumplen el filtro sin paginar, no el tamaño de `items`).
public typealias ForumThreadPage = Components.Schemas.ThreadListPage
/// El detalle de un hilo del foro, con todos sus comentarios.
public typealias ForumThreadDetail = Components.Schemas.ThreadDetailRead
/// Un comentario de un hilo del foro.
public typealias ForumComment = Components.Schemas.CommentRead

/// El generador ya le da `id: Int`; declararlo aquí (dentro del propio
/// paquete, no en el target de la app) evita el warning de conformidad
/// retroactiva y permite usar los temas directamente en un `ForEach`.
extension Track: Identifiable {}
extension CollectionSummary: Identifiable {}
extension CollectionEdition: Identifiable {}
extension CollectionTag: Identifiable {}
extension ForumThreadSummary: Identifiable {}
extension SubforumSummary: Identifiable {}
extension ForumComment: Identifiable {}
