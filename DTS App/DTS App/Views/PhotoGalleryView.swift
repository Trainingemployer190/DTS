//
//  PhotoGalleryView.swift
//  DTS App
//
//  Created by System on 10/4/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

struct PhotoGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [CapturedPhoto]
    @State private var selectedIndex: Int

    init(photos: [CapturedPhoto], initialIndex: Int = 0) {
        self.photos = photos
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                    .contentShape(Rectangle()) // Make entire black background tappable

                if !photos.isEmpty {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            ZoomableImageView(image: photo.image)
                                .tag(index)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle()) // Make entire frame swipeable
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No photos available")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(selectedIndex + 1) of \(photos.count)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1), 4) // Limit zoom between 1x and 4x
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1 {
                                withAnimation {
                                    scale = 1
                                    offset = .zero
                                }
                            }
                        }
                )
                .highPriorityGesture(
                    // Only capture drag when significantly zoomed in - allows TabView swipe otherwise
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if scale > 1.2 { // Only pan when actually zoomed in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            if scale > 1.2 {
                                lastOffset = offset
                            }
                        },
                    including: scale > 1.2 ? .all : .none // Only enable this gesture when zoomed
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2
                        }
                    }
                }
        }
    }
}
#endif
