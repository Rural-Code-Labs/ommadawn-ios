//
//  ImageViewerView.swift
//  ommadawn
//
//  Visor de imágenes a pantalla completa. Soporta zoom por pellizco y
//  doble toque, desplazamiento al hacer zoom y deslizamiento horizontal
//  entre imágenes. El botón de compartir usa el ShareLink del sistema.
//

import SwiftUI

struct ImageViewerView: View {
    let images: [URL]
    @State var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                    ZoomableAsyncImage(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: Circle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .overlay(alignment: .topTrailing) {
            if images.indices.contains(selectedIndex) {
                ShareLink(item: images[selectedIndex]) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Imagen individual con zoom y pan

private struct ZoomableAsyncImage: View {
    let url: URL

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureOffset: CGSize = .zero

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale * gestureScale)
                    .offset(
                        x: offset.width + gestureOffset.width,
                        y: offset.height + gestureOffset.height
                    )
                    .gesture(pinchGesture)
                    .simultaneousGesture(panGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.3)) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                            } else {
                                scale = 2.5
                            }
                        }
                    }
            case .empty:
                ProgressView().tint(.white)
            case .failure:
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No se pudo cargar la imagen")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .updating($gestureScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let newScale = max(1, min(5, scale * value.magnification))
                withAnimation(.spring(duration: 0.2)) {
                    scale = newScale
                    if newScale <= 1 { offset = .zero }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                guard scale > 1 else { return }
                state = value.translation
            }
            .onEnded { value in
                guard scale > 1 else { return }
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }
}
