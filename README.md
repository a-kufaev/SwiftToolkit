# SwiftToolkit

A collection of small, focused Swift utilities, polished for reuse across projects.

SwiftToolkit is organized into granular library products, split along **dependency boundaries** so you only pull in what you use — the core has no third-party dependencies and links nothing beyond `Foundation` and `Observation`, while UI helpers live in a separate product so non-UI consumers never link SwiftUI/UIKit.

## Products

| Product | Depends on | What's inside |
|---------|-----------|---------------|
| **SwiftToolkit** | Foundation, Observation | Concurrency helpers, Codable property wrappers, the Store pattern |
| **SwiftToolkitUI** | SwiftUI, UIKit | View extensions, the `Buildable` builder, tap animations, helpers, `HeaderPageScrollView`, the photos picker |
| **SwiftToolkitVideo** | AVKit, SwiftToolkit, SwiftToolkitUI | A SwiftUI `VideoPlayer`, a looping player, and a playback-metrics pipeline |
| **SwiftToolkitImage** | [Kingfisher](https://github.com/onevcat/Kingfisher) | `AdaptiveImageView` — resolution-aware remote image loading |

> Products are split by dependency boundary: depend only on what you use. For example, only `SwiftToolkitImage` pulls in Kingfisher — consumers of the other products never fetch or link it.

## Requirements

- Swift 6.0+
- iOS 18.0+ / macOS 15.0+ / tvOS 18.0+ / watchOS 11.0+ / visionOS 2.0+

UIKit-only helpers in `SwiftToolkitUI` (blur views, hex colors, the photos picker, scene-state observation) are gated behind `#if canImport(UIKit)`, so the cross-platform pieces still build on macOS.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/a-kufaev/SwiftToolkit.git", from: "1.0.0")
]
```

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "SwiftToolkit", package: "SwiftToolkit"),
        .product(name: "SwiftToolkitUI", package: "SwiftToolkit")
    ]
)
```

## `SwiftToolkit` — core

### Concurrency

- **`AsyncSignal`** — a one-way event signal built on `AsyncStream` (`send` / `finish` / `for await`).
- **`AsyncQueue`** — a serial async task queue with `enqueue` and `enqueueAndWait`.
- **`BroadcastStream`** — an actor-based pub/sub that fans one event out to many subscribers.
- **`TaskDebouncer`** — debounces async work; only the last call within the window runs.
- **`InFlightTaskDeduplicator`** — coalesces concurrent operations sharing a key into a single task.
- **`WebSocket`** / **`ReconnectableWebSocket`** — an `async`/`await` WebSocket client over `URLSessionWebSocketTask` with message/state streams, heartbeats, and automatic reconnection.

```swift
let debouncer = TaskDebouncer(seconds: 0.3)
debouncer.debounce { await search(query) }
```

### Codable

BetterCodable-style property wrappers for resilient decoding:

- **`@DefaultCodable`** + strategies (`@DefaultFalseCodable`, `@DefaultTrueCodable`).
- **`@LossyCodableArray`** / **`@LossyOptionalCodable`** — tolerate invalid elements/values, with an opt-in **`LossyDecodingReporter`** (`decoder.userInfo[.lossyDecodingReporter]`) to observe what they drop.
- **`@DateValueCodable`** with `TimestampCodableStrategy` / `MillisecondsTimestampCodableStrategy`.
- **`RawJSONObject`** — decode arbitrary, dynamically-shaped JSON.
- **`SafetyEnum`** — forward-compatible enums that fall back to a `failure` case.

```swift
struct Account: Decodable {
    @DefaultFalseCodable var isBlocked: Bool
    @DateValueCodable<TimestampCodableStrategy> var openedAt: Date
    @LossyCodableArray var cards: [Card]
}
```

### Store

An observable, single-source-of-truth data-store pattern for SwiftUI (`LoadingPhase`, `DataStore`, `AsyncDataStore`). See the dedicated [Store README](Sources/SwiftToolkit/Store/README.md).

```swift
final class ProfileStore: AsyncDataStore<Profile> {
    override func fetch(force: Bool) async throws -> Profile {
        try await service.loadProfile(force: force)
    }
}
```

## `SwiftToolkitUI`

SwiftUI/UIKit building blocks:

- **View extensions** — `if`, `ifLet`, `modify`, `onFirstAppear`, `readSize`/`bindSize`, square `frame(_:)`, `fillFrame`.
- **`Buildable`** — a fluent builder protocol (`map { $0.x = y }`) for configuring value types.
- **Tap animations** — `onTapGesture(animation: .bounce / .fade / .fill(color))`.
- **Helpers** — `HiddenMode`, `flippedUpsideDown()`, `shake(isShaking:)`, `FadingScrollView`, `Color(hex:)`, `VisualEffectView`, `onSceneStateChanged`.
- **`HeaderPageScrollView`** — a horizontally paged scroll view with a shared collapsible header and sticky page picker.
- **`imagesPicker(isPresented:selection:)`** — a `PhotosUI` image picker modifier.

```swift
Text("Tap me")
    .onTapGesture(animation: .bounce) { handleTap() }
```

## `SwiftToolkitVideo`

An AVKit-backed video stack:

- **`VideoPlayer`** — a `UIViewRepresentable` wrapper over `AVPlayer` with a configurable `videoGravity`.
- **`VideoPlayerWithControls`** — a higher-level player with playback controls, PiP, and Now Playing.
- **`LoopingVideoPlayerModel`** — a queue-player + looper model.
- **Metrics** — an `@Observable` facade streaming buffer/timeline/lifecycle events via `AsyncSignal`.

## `SwiftToolkitImage`

- **`AdaptiveImageView`** — picks the best image variant for the target size, shows a cached lower-res image as a placeholder, and loads via [Kingfisher](https://github.com/onevcat/Kingfisher).

## License

SwiftToolkit is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
