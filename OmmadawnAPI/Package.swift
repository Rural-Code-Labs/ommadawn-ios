// swift-tools-version: 6.2
//
//  OmmadawnAPI — capa de red de la app.
//
//  Paquete local (no publicado) que contiene el cliente HTTP TIPADO de la
//  API `ommadawn-api`, generado con swift-openapi-generator a partir del
//  contrato `openapi.json` vendorizado en Sources/OmmadawnAPI/.
//
//  El código del cliente NO se escribe ni se comitea a mano: lo genera el
//  build plugin en cada compilación. Si la API cambia, se refresca el
//  `openapi.json` y un cambio incompatible se detecta al compilar.
//

import PackageDescription

let package = Package(
    name: "OmmadawnAPI",
    // Mismos mínimos que la app (deployment target 26.5).
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: "OmmadawnAPI", targets: ["OmmadawnAPI"]),
    ],
    dependencies: [
        // El generador: se usa como BUILD TOOL PLUGIN (genera en cada build).
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        // Tipos base que usa el código generado (Client, errores, etc.).
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        // Transporte HTTP sobre URLSession (nativo de Apple).
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "OmmadawnAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            plugins: [
                // Al compilar, este plugin lee openapi.json + la config y
                // genera Client/Types dentro de este target.
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
    ]
)
