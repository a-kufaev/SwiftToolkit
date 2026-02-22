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

// swiftlint:disable file_length

import SwiftUI

/// A horizontally paged scroll view with a shared collapsible header and a sticky page picker.
///
/// `HeaderPageScrollView` renders a set of pages in a horizontal pager, sharing a single header
/// and picker across all of them. The header collapses on vertical scroll and stays consistent
/// when switching pages.
///
/// ## Usage
///
/// ```swift
/// HeaderPageScrollView(
///     activePageIndex: $activePageIndex,
///     header: { ProfileHeaderView() },
///     pagePicker: { index, progress in
///         SegmentPicker(activePageIndex: index, scrollProgress: progress)
///     },
///     pages: {
///         FeedView()
///         LikesView()
///         DraftsView()
///     }
/// )
/// .refreshable { await viewModel.reload() }
/// ```
///
/// ## Architecture
///
/// 1. **Horizontal pager** — a full-screen `ScrollView(.horizontal)` with one vertical scroll
///    view per page.
/// 2. **Page content** — each page is a `ScrollView(.vertical)`. The header and picker are
///    rendered at the top of the *active* page via `slidingOverlay`; other pages get a `Spacer`.
/// 3. **Sliding overlay** — on the active page the header/picker are offset by `-scrollView.minX`
///    every frame, keeping them visually pinned to the screen while physically residing inside
///    the vertical scroll view. This gives native vertical gesture routing without UIKit hacks.
///
/// Vertical scroll positions are synchronized across pages: on horizontal swipe start or
/// programmatic `activePageIndex` change, siblings are aligned to the active page's header
/// collapse amount.
///
/// ## Design Decisions
///
/// **Header as an overlay above the pager** was rejected: SwiftUI cannot forward gestures
/// through an overlay, so vertical scrolling breaks when touching header content. This is a
/// fundamental hit-testing limitation of SwiftUI/UIKit with no pure-SwiftUI fix.
///
/// **Header only in the first page, others offset by Y** was rejected: when sibling pages
/// scroll, the header stays put and only moves at the end — the UI breaks. The correct Y-offset
/// math was complex with many edge cases, and zIndex tricks didn't fix interactivity issues
/// caused by sibling pages overlapping the header.
///
/// **Single outer vertical scroll + horizontal pager + per-page vertical scroll** was rejected:
/// SwiftUI has no equivalent of UIScrollViewDelegate math for smooth scroll handoff between
/// nested vertical scroll views.
///
/// **Conclusion.** The current `slidingOverlay` + `.visualEffect` counter-scroll approach has
/// known limitations, but is clean, lightweight, and stable enough for most real-world needs.
///
/// ## Limitations
///
/// - **All pages are always rendered.** The pager uses `HStack`, not `LazyHStack`. Switching
///   to `LazyHStack` breaks scroll geometry tracking and causes chaotic animations on tab
///   switches due to lazy materialization timing conflicts with `visualEffect`.
///
/// - **Header and picker are recreated on tab switch.** `slidingOverlay` tears down the active
///   page's header/picker and builds the new page's. `.transition(.identity)` hides the visual
///   jump, but the views are recreated — internal state is not preserved.
///
/// - **Unstable `refreshable` behavior.** Two symptoms: (1) rarely, the scroll gets stuck in a
///   heavily pulled state — the spinner keeps spinning but doesn't snap to the top or release;
///   (2) while the spinner is visible, taps on all screen elements miss — the content is visually
///   shifted down by the spinner, but the hit targets remain at their pre-spinner positions.
public struct HeaderPageScrollView<Header: View, PagePicker: View, Pages: View>: View {

    /// `activePageIndex` — snapped page index (nil until first layout).
    /// `scrollProgress` — continuous fractional page position from the raw horizontal offset:
    /// 0.0 = page 0, 1.0 = page 1, 0.7 = 70 % of the way from page 0 to page 1.
    /// Use `scrollProgress` for real-time effects (opacity, indicator position);
    /// use `activePageIndex` only for discrete selection state.
    public typealias PagePickerBuilder = (
        _ activePageIndex: Binding<Int?>,
        _ scrollProgress: Double
    ) -> PagePicker

    @Binding
    var activePageIndex: Int?
    private var safeActivePageIndex: Int {
        activePageIndex ?? .zero
    }

    @ViewBuilder
    private var header: () -> Header
    @ViewBuilder
    private var pagePicker: PagePickerBuilder
    @ViewBuilder
    private var pages: () -> Pages

    // MARK: - Configuration

    /// Pull-to-refresh handler. Set via `.refreshable(action:)`.
    private var refreshAction: (@Sendable () async -> Void)?
    /// Distance in points over which the header fades out before fully collapsing. Default 28.
    private var headerFadeDistance: CGFloat = 28

    // MARK: - State

    @State
    private var headerHeight: CGFloat = .zero
    @State
    private var pagePickerHeight: CGFloat = .zero

    // MARK: - Vertical Scrolls

    @State
    private var scrollGeometries: [ScrollGeometry] = []
    @State
    private var scrollPositions: [ScrollPosition] = []

    // MARK: - Horizontal Scroll

    @State
    private var horizontalScrollGeometry = ScrollGeometry()
    @State
    private var horizontalScrollDisabled = false
    @State
    private var horizontalScrollPhase: ScrollPhase = .idle

    // MARK: - Init

    public init(
        activePageIndex: Binding<Int?>,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder pagePicker: @escaping PagePickerBuilder,
        @ViewBuilder pages: @escaping () -> Pages
    ) {
        _activePageIndex = activePageIndex
        self.header = header
        self.pagePicker = pagePicker
        self.pages = pages
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            horizontalPager(size: geometry.size)
        }
        // Blocks horizontal page swiping when a drag starts in the header zone.
        // Attached to the root so the gesture observes all touches simultaneously
        // without capturing them. See `headerZoneHorizontalBlockGesture`.
        .simultaneousGesture(headerZoneHorizontalBlockGesture)
    }

    // MARK: - Horizontal Pager

    /// Full-screen paging ScrollView. Each child is a vertically scrollable page
    /// sized to exactly one screen width.
    private func horizontalPager(size: CGSize) -> some View {
        ScrollView(.horizontal) {
            // HStack instead of LazyHStack — see Limitations.
            HStack(spacing: .zero) {
                // `Group(subviews:)` decomposes the opaque `Pages` ViewBuilder into
                // individually addressable subviews to wrap each in its own vertical ScrollView.
                Group(subviews: pages()) { collection in
                    // Pages are rendered only after scroll storage is allocated.
                    // On first render the arrays are empty — `ensureCapacity` fills them.
                    if scrollPositions.count < collection.count {
                        Color.clear
                            .onAppear { ensureCapacity(for: collection.count) }
                    } else {
                        ForEach(.zero ..< collection.count, id: \.self) { index in
                            pageContent(at: index, size: size, collection: collection)
                        }
                        .onAppear { selectInitialPageIfNeeded() }
                    }
                }
            }
            // Lets `.scrollTargetBehavior(.paging)` know the size of each page.
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        // Two-way binding: tracks the visible page and allows programmatic page changes.
        .scrollPosition(id: $activePageIndex)
        .scrollIndicators(.hidden)
        // Disabled while a horizontal drag in the header zone is in progress.
        .scrollDisabled(horizontalScrollDisabled)
        .onScrollGeometryChange(for: ScrollGeometry.self, of: \.self) { _, newValue in
            horizontalScrollGeometry = newValue
        }
        .onChange(of: activePageIndex) { oldIndex, _ in
            guard let oldIndex, horizontalScrollPhase == .idle else { return }
            onActivePageChangedExternally(from: oldIndex)
        }
        .onScrollPhaseChange { _, newPhase in
            horizontalScrollPhase = newPhase
            if newPhase == .interacting { onHorizontalScrollBegan() }
            if newPhase == .idle { restoreScrollPositionIfCorrupted() }
        }
    }

    /// Ensures `scrollGeometries` and `scrollPositions` have at least `count` elements.
    /// Called once on first page appearance, removing the need to pass `pagesCount` at init.
    private func ensureCapacity(for count: Int) {
        guard scrollPositions.count < count else { return }
        let deficit = count - scrollPositions.count
        scrollGeometries.append(contentsOf: Array(repeating: ScrollGeometry(), count: deficit))
        scrollPositions.append(contentsOf: Array(repeating: ScrollPosition(), count: deficit))
    }

    // MARK: - Page Content

    /// Each page is a vertical ScrollView with the header and picker at the top:
    /// - On the active page `slidingOverlay` renders the real header/picker,
    ///   counter-scrolling them horizontally to keep them visually pinned to the screen.
    /// - On inactive pages `slidingOverlay` renders a same-height Spacer,
    ///   preserving layout geometry without instantiating the real views.
    ///
    /// The picker is a Section header inside `LazyVStack(pinnedViews:)`, so it sticks
    /// to the top once the collapsible header scrolls away.
    private func pageContent(at index: Int, size: CGSize, collection: SubviewsCollection) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: .zero, pinnedViews: [.sectionHeaders]) {
                slidingOverlay(isActive: safeActivePageIndex == index, savedHeight: $headerHeight) {
                    header()
                        .visualEffect { view, proxy in
                            let headerOffset = -proxy.frame(in: .scrollView(axis: .vertical)).minY
                            return view.opacity(headerOpacity(offset: headerOffset))
                        }
                }

                Section {
                    collection[index]
                        // Min height = screen height minus the pinned picker height.
                        // Ensures short content still fills the visible area.
                        .frame(minHeight: size.height - pagePickerHeight, alignment: .top)
                } header: {
                    slidingOverlay(isActive: safeActivePageIndex == index, savedHeight: $pagePickerHeight) {
                        pagePicker($activePageIndex, horizontalScrollProgress)
                    }
                }
            }
        }
        .ifLet(refreshAction) { $0.refreshable(action: $1) }
        .onScrollGeometryChange(for: ScrollGeometry.self, of: \.self) { _, newValue in
            scrollGeometries[index] = newValue
        }
        .scrollPosition($scrollPositions[index])
        // Each page fills exactly one screen width inside the HStack.
        .frame(width: size.width)
        // Allows the counter-scrolled header/picker to visually overflow the page's
        // clip region during horizontal swipe transitions.
        .scrollClipDisabled()
        // Active page renders above its neighbours during the swipe transition.
        // Any value > 0 works since all siblings default to zIndex 0.
        .zIndex(safeActivePageIndex == index ? 1 : 0)
    }

    /// On the active page, renders `content` counter-scrolled to stay pinned to the screen.
    /// On inactive pages, renders a same-height `Spacer` to preserve layout geometry.
    ///
    /// `.visualEffect` offsets the view by `-minX` of its frame in the horizontal scroll view's
    /// coordinate space every frame. Since `minX` equals the page's current horizontal offset,
    /// subtracting it keeps the view at a fixed screen position regardless of swipe progress.
    ///
    /// - Parameters:
    ///   - isActive: Whether this is the currently visible page.
    ///   - savedHeight: Updated by the active page with the measured content height;
    ///     drives the Spacer size on inactive pages.
    ///   - content: The view to pin — either the collapsible header or the page picker.
    @ViewBuilder
    private func slidingOverlay(
        isActive: Bool,
        savedHeight: Binding<CGFloat>,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ZStack {
            // `.transition(.identity)` on both branches suppresses the default SwiftUI
            // insert/remove animation when the active page changes.
            if isActive {
                content()
                    .visualEffect { view, proxy in
                        view.offset(x: -proxy.frame(in: .scrollView(axis: .horizontal)).minX)
                    }
                    .contentShape(Rectangle())
                    .readHeight(savedHeight)
                    .transition(.identity)
            } else {
                Spacer()
                    .frame(height: savedHeight.wrappedValue)
                    .transition(.identity)
            }
        }
        // Prevents glass/material views inside the header and picker from animating
        // their appearance when the active page changes. Targets only `isActive` changes,
        // so the scroll-driven visualEffect offset is not affected.
        .animation(.none, value: isActive)
    }
}

// MARK: - Header Zone Gesture

extension HeaderPageScrollView {

    /// Blocks horizontal page swiping when a drag starts in the sticky header zone.
    /// Only fires when the dominant direction is horizontal; vertical drags are ignored
    /// so the underlying vertical ScrollView handles them without interference.
    ///
    /// Attached to the root via `.simultaneousGesture` rather than the header itself:
    /// the header lives inside a vertical ScrollView, so a gesture on it would compete
    /// with vertical scrolling. On the root it only observes without capturing.
    private var headerZoneHorizontalBlockGesture: some Gesture {
        DragGesture(minimumDistance: .zero)
            .onChanged { value in
                guard value.startLocation.y < visibleStickyHeaderHeight else { return }
                let translation = value.translation
                horizontalScrollDisabled = abs(translation.width) > abs(translation.height)
            }
            .onEnded { _ in
                horizontalScrollDisabled = false
            }
    }

    /// Currently visible height of the sticky header zone.
    /// Shrinks as the user scrolls down and the collapsible header slides away.
    private var visibleStickyHeaderHeight: CGFloat {
        headerHeight + pagePickerHeight - headerOffset(for: safeActivePageIndex)
    }
}

// MARK: - Scroll Calculations

extension HeaderPageScrollView {

    /// Continuous fractional page index derived from the raw horizontal scroll offset.
    /// `containerSize.width` equals one page width since each page fills the screen.
    private var horizontalScrollProgress: Double {
        let pageWidth = horizontalScrollGeometry.containerSize.width
        guard pageWidth > .zero else { return .zero }
        return Double(horizontalScrollGeometry.offsetX / pageWidth)
    }

    /// Active page's vertical scroll offset clamped to `[0...headerHeight]`.
    /// Represents how far the header has been scrolled away.
    private func headerOffset(for pageIndex: Int) -> CGFloat {
        guard scrollGeometries.indices.contains(pageIndex) else { return .zero }
        return min(scrollGeometries[pageIndex].offsetY, headerHeight)
    }

    /// Returns `true` if the header is still at least partially visible.
    private func isHeaderVisible(for pageIndex: Int) -> Bool {
        headerOffset(for: pageIndex) < headerHeight
    }

    /// Fades the header from fully visible to hidden over the last `headerFadeDistance` points.
    private func headerOpacity(offset: CGFloat) -> CGFloat {
        let remaining = headerHeight - offset
        return max(0, min(1, remaining / headerFadeDistance))
    }
}

// MARK: - Page Lifecycle

extension HeaderPageScrollView {

    /// Selects the first page on initial appearance if no selection has been made yet.
    private func selectInitialPageIfNeeded() {
        guard activePageIndex == nil else { return }
        activePageIndex = .zero
    }

    /// Called when the user begins a horizontal swipe.
    /// Syncs all vertical scroll positions before the new page becomes visible,
    /// preventing the header from jumping on transition.
    private func onHorizontalScrollBegan() {
        syncScrollViews(from: safeActivePageIndex)
    }

    /// Called when the horizontal scroll settles.
    /// Compares `activePageIndex` against the real scroll position and corrects it if they
    /// differ — this happens when a programmatic page change (e.g. from the picker) is
    /// interrupted by user interaction and the scroll stops at the wrong page.
    private func restoreScrollPositionIfCorrupted() {
        let actualPageIndex = Int(round(horizontalScrollProgress))
        guard activePageIndex != actualPageIndex else { return }
        activePageIndex = actualPageIndex
    }

    /// Called when `activePageIndex` changes externally (not via a user swipe).
    /// The horizontal scroll updates itself, but vertical positions need manual sync
    /// before the transition animation begins.
    private func onActivePageChangedExternally(from pageIndex: Int) {
        syncScrollViews(from: pageIndex)
    }
}

// MARK: - Scroll Synchronization

extension HeaderPageScrollView {

    /// Aligns sibling pages to the same header collapse offset so the header position
    /// is consistent when switching pages.
    private func syncScrollViews(from pageIndex: Int) {
        let targetOffset = headerOffset(for: pageIndex)
        let isHeaderCollapsing = targetOffset < headerHeight

        for index in scrollPositions.indices where index != pageIndex {
            // Only sync pages where the header is still at least partially visible —
            // pages already scrolled past the header don't need adjustment.
            let siblingShowsHeader = isHeaderVisible(for: index)
            guard siblingShowsHeader || isHeaderCollapsing else { continue }
            scrollPositions[index].scrollTo(y: targetOffset)
        }
    }
}

// MARK: - Builder-style API

extension HeaderPageScrollView: Buildable {

    /// Adds pull-to-refresh to the active page.
    public func refreshable(action: @escaping @Sendable () async -> Void) -> Self {
        map { $0.refreshAction = action }
    }

    /// Sets the distance in points over which the header fades out before fully collapsing.
    ///
    /// Defaults to `28`. Smaller values produce a sharper fade; larger values a more gradual one.
    public func headerFadeDistance(_ distance: CGFloat) -> Self {
        map { $0.headerFadeDistance = distance }
    }
}

// MARK: - View + Height Reading

extension View {
    fileprivate func readHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) {
            $0.size.height
        } action: { newValue in
            height.wrappedValue = newValue
        }
    }
}

// MARK: - ScrollGeometry Helpers

extension ScrollGeometry {
    fileprivate init() {
        self.init(
            contentOffset: .zero,
            contentSize: .zero,
            contentInsets: EdgeInsets(),
            containerSize: .zero
        )
    }

    fileprivate var offsetY: CGFloat {
        contentOffset.y + contentInsets.top
    }

    fileprivate var offsetX: CGFloat {
        contentOffset.x + contentInsets.leading
    }
}

// swiftlint:enable file_length
