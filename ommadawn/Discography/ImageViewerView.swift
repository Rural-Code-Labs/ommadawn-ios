//
//  ImageViewerView.swift
//  ommadawn
//
//  Visor de imágenes a pantalla completa. Desliza entre imágenes con el
//  scroll paginado (desactivado al hacer zoom). Zoom por pellizco y doble
//  toque. El botón de compartir usa el ShareLink del sistema.
//

import SwiftUI

struct ImageViewerView: View {
    let images: [URL]
    @State var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var isZoomed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                        ZoomableAsyncImage(url: url, isZoomed: $isZoomed)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding<Int?>(
                get: { selectedIndex },
                set: { selectedIndex = $0 ?? selectedIndex }
            ))
            .scrollDisabled(isZoomed)
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
        .overlay(alignment: .bottom) {
            if images.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<images.count, id: \.self) { i in
                        Circle()
                            .fill(i == selectedIndex ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Imagen individual con zoom y pan

private struct ZoomableAsyncImage: View {
    let url: URL
    @Binding var isZoomed: Bool

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
                    .simultaneousGesture(panGesture, including: isZoomed ? .all : .none)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.3)) {
                            if scale > 1 {
                                scale = 1; offset = .zero; isZoomed = false
                            } else {
                                scale = 2.5; isZoomed = true
                            }
                        }
                    }
            case .empty:
                ProgressView().tint(.white)
            case .failure:
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle).foregroundStyle(.white.opacity(0.5))
                    Text("No se pudo cargar la imagen")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))
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
                isZoomed = newScale > 1
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }
}
