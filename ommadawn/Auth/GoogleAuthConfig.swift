//
//  GoogleAuthConfig.swift
//  ommadawn
//
//  Client IDs de Google Sign-In (Google Cloud Console, proyecto Rural Code Labs).
//  No son secretos — van embebidos en el binario y son públicos por diseño de OAuth
//  para clientes nativos — pero se centralizan aquí para no repetirlos entre
//  ommadawnApp (configuración del SDK) y el Info.plist (esquema de URL).
//

enum GoogleAuthConfig {
    /// Client ID de tipo iOS: identifica esta app ante Google, ligado al bundle id
    /// com.ruralcodelabs.ommadawn. El SDK lo usa para lanzar el flujo de login.
    static let clientID = "681872954393-b06umu1c7bbjh74k6ertfcdrks3j6bkd.apps.googleusercontent.com"

    /// Client ID de tipo "Aplicación web": es la audiencia (`aud`) que llevará el ID
    /// token, no un flujo web real. Al fijarlo como `serverClientID`, la API puede
    /// verificar tokens con un único Client ID sin importar la plataforma de origen
    /// (útil cuando llegue el cliente Android, que usará otro Client ID de tipo Android
    /// pero la misma audiencia de servidor).
    static let serverClientID = "681872954393-j7sc19l0opgbhap8c698kj1f3iok8m00.apps.googleusercontent.com"
}
