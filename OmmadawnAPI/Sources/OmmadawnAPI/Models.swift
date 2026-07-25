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
