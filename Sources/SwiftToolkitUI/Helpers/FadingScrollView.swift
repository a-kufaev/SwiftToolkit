//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftToolkit open source project
//
// Copyright (c) 2025 Artem Kufaev
// Licensed under MIT License
//
// See https://github.com/a-kufaev/SwiftToolkit/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import SwiftUI

/// A `ScrollView` that fades its content near the leading and trailing edges using a gradient mask.
///
/// Reference: https://stackoverflow.com/a/79158800
public struct FadingScrollView<Content: View>: View {

    private let axis: Axis.Set

    private let isStartFading: Bool
    private let isEndFading: Bool

    private let maxZoneSize: CGFloat

    @State
    private var startZoneSize = CGFloat.zero
    @State
    private var endZoneSize = CGFloat.zero

    private let content: () -> Content

    private var realStartZoneSize: CGFloat {
        max(.zero, isStartFading ? startZoneSize : .zero)
    }

    private var realEndZoneSize: CGFloat {
        max(.zero, isEndFading ? endZoneSize : .zero)
    }

    public init(
        _ axis: Axis.Set = .vertical,
        isStartFading: Bool = true,
        isEndFading: Bool = true,
        maxZoneSize: CGFloat = 100,
        content: @escaping () -> Content
    ) {
        self.axis = axis
        self.isStartFading = isStartFading
        self.isEndFading = isEndFading
        self.maxZoneSize = maxZoneSize
        self.content = content
    }

    public var body: some View {
        GeometryReader { scrollProxy in
            ScrollView(axis) {
                content()
                    .onGeometryChange(for: CGRect.self) { contentProxy in
                        contentProxy.frame(in: .scrollView)
                    } action: { frame in
                        // Calculating zone sizing
                        let startZoneSize: CGFloat
                        let endZoneSize: CGFloat

                        switch axis {
                        case .horizontal:
                            startZoneSize = min(-frame.minX, maxZoneSize)
                            endZoneSize = min(frame.maxX - scrollProxy.size.width, maxZoneSize)
                        case .vertical:
                            startZoneSize = min(-frame.minY, maxZoneSize)
                            endZoneSize = min(frame.maxY - scrollProxy.size.height, maxZoneSize)
                        default:
                            return
                        }

                        // Applying new zone sizes
                        if self.startZoneSize != startZoneSize {
                            self.startZoneSize = startZoneSize
                        }
                        if self.endZoneSize != endZoneSize {
                            self.endZoneSize = endZoneSize
                        }
                    }
            }
        }
        .mask {
            switch axis {
            case .horizontal:
                HStack(spacing: .zero) {
                    mask
                }
            case .vertical:
                VStack(spacing: .zero) {
                    mask
                }
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var mask: some View {
        LinearGradient(
            colors: [.clear, .black],
            startPoint: axis == .vertical ? .top : .leading,
            endPoint: axis == .vertical ? .bottom : .trailing
        )
        .frame(width: axis == .horizontal ? realStartZoneSize : nil)
        .frame(height: axis == .vertical ? realStartZoneSize : nil)

        Color.black

        LinearGradient(
            colors: [.black, .clear],
            startPoint: axis == .vertical ? .top : .leading,
            endPoint: axis == .vertical ? .bottom : .trailing
        )
        .frame(width: axis == .horizontal ? realEndZoneSize : nil)
        .frame(height: axis == .vertical ? realEndZoneSize : nil)
    }
}
