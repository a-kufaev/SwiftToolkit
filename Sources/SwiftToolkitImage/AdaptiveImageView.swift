//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftToolkit open source project
//
// Copyright (c) 2026 Artem Kufaev
// Licensed under MIT License
//
// See https://github.com/a-kufaev/SwiftToolkit/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

#if canImport(UIKit)
import Kingfisher
import SwiftUI

/// A view that shows one image chosen from multiple resolution variants: it picks the variant that best matches
/// `targetSize`, loads it with Kingfisher (with disk cache), and optionally shows a lower‑resolution cached variant as
/// placeholder while the target is loading.
///
/// - Only one image is drawn at a time; lower‑res assets are used only as placeholders when already in cache.
/// - Status (idle / loading / loaded / failure) is reported via `onLoadStatusChange`.
public struct AdaptiveImageView: View {
    
    private let variants: [AdaptiveImageVariant]
    private let targetSize: CGSize
    private let contentMode: SwiftUI.ContentMode
    private let onLoadStatusChange: ((AdaptiveImageLoadStatus) -> Void)?
    
    @State
    private var cachedPlaceholderURL: URL?
    @State
    private var loadStatus: AdaptiveImageLoadStatus = .idle
    
    /// Variants sorted by size (ascending area).
    private var sortedBySize: [AdaptiveImageVariant] {
        variants.sorted { $0.area < $1.area }
    }
    
    /// The variant used for the main image: smallest variant with area >= target area, or the largest if none.
    private var targetVariant: AdaptiveImageVariant? {
        let targetArea = targetSize.width * targetSize.height * UIScreen.main.scale
        let sorted = sortedBySize
        return sorted.first { $0.area >= targetArea } ?? sorted.last
    }
    
    /// Lower‑quality variants (smaller than target), best to worst, used only for cached placeholder.
    private var lowerQualityVariants: [AdaptiveImageVariant] {
        guard let target = targetVariant else { return [] }
        return sortedBySize
            .filter { $0.area < target.area }
            .reversed()
    }
    
    public init(
        variants: [AdaptiveImageVariant],
        targetSize: CGSize,
        contentMode: SwiftUI.ContentMode = .fill,
        onLoadStatusChange: ((AdaptiveImageLoadStatus) -> Void)? = nil
    ) {
        self.variants = variants
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.onLoadStatusChange = onLoadStatusChange
    }
    
    public var body: some View {
        content
            .task(id: targetVariant?.url) {
                loadStatus = targetVariant != nil ? .loading : .idle
                await resolveCachedPlaceholder()
            }
            .onChange(of: loadStatus) { _, newStatus in
                onLoadStatusChange?(newStatus)
            }
            .onAppear {
                reportStatusIfNeeded()
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if let target = targetVariant {
            KFImage(target.url)
                .onSuccess { _ in
                    loadStatus = .loaded
                }
                .onFailure { error in
                    loadStatus = .failure(error)
                }
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .background {
                    if loadStatus != .loaded {
                        placeholderView
                    }
                }
        } else {
            Color.clear
                .onAppear {
                    loadStatus = .idle
                }
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        if let url = cachedPlaceholderURL {
            KFImage(url)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        }
    }
}

// MARK: - Logic

extension AdaptiveImageView {

    private func reportStatusIfNeeded() {
        onLoadStatusChange?(loadStatus)
    }

    private func resolveCachedPlaceholder() async {
        let lower = lowerQualityVariants
        guard !lower.isEmpty else {
            cachedPlaceholderURL = nil
            return
        }
        let cache = ImageCache.default
        for variant in lower {
            let key = variant.url.cacheKey
            let result = try? await cache.retrieveImage(forKey: key)
            if result?.image != nil {
                cachedPlaceholderURL = variant.url
                return
            }
        }
        cachedPlaceholderURL = nil
    }
}

extension AdaptiveImageVariant {
    fileprivate var area: CGFloat { size.width * size.height }
}
#endif
