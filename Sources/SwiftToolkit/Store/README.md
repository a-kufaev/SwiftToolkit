# Store

A small, opinionated approach to **observable, single-source-of-truth data stores** for SwiftUI, built on Swift's `Observation` framework.

The pattern is designed for data-heavy screens where many independent pieces of data load, refresh, and fail independently. Instead of one giant view model, each piece of data gets its own small **store**, and the screen simply composes them.

## The pieces

### `LoadingPhase`
A four-state lifecycle: `.idle → .loading → .loaded` / `.error`. This is what your UI switches on.

### `DataStore`
An `@MainActor`, `Observable` protocol describing a container that owns exactly one resource:

```swift
var phase: LoadingPhase { get }
var content: Content? { get }
var lastError: Error? { get }
var isContentStale: Bool { get async }

func load(force: Bool) async throws -> Content
func reset()
```

Because it's `Observable`, SwiftUI views observe it directly and re-render off `phase` / `content`.

### `AsyncDataStore<Content>`
A ready-to-subclass base class implementing the lifecycle with the **template-method pattern** — you only override `fetch(force:)`:

```swift
@MainActor
final class ProfileStore: AsyncDataStore<Profile> {
    private let service: ProfileService

    init(service: ProfileService) {
        self.service = service
        super.init()
    }

    override func fetch(force: Bool) async throws -> Profile {
        try await service.loadProfile(force: force)
    }
}
```

## Key behaviors

- **Silent refresh.** `load(force:)` only switches to `.loading` when there is no `content` yet. If data is already on screen, refreshes happen without flashing a spinner.
- **Resilient errors.** If a refresh fails but content already exists, the store stays `.loaded` and records `lastError`. Only the *first* load with no content transitions to `.error`.
- **Cancellation-safe.** `CancellationError` is rethrown without corrupting the phase.
- **Staleness is the store's business.** Override `isContentStale` to consult an underlying source (a repository TTL, a service version, …) so the decision to refresh lives in the data layer, not in a UI timer.
- **Optimistic updates.** Use `set(_:)` to push a known value and mark it `.loaded` without fetching.

## Composing a screen

A screen owns several stores and renders each independently:

```swift
@MainActor
@Observable
final class MainScreenModel {
    let accounts = AccountsStore(...)
    let deposits = DepositStore(...)
    let tariff = TariffStore(...)

    func onAppear() async {
        async let a: () = try? accounts.load()
        async let d: () = try? deposits.load()
        async let t: () = try? tariff.load()
        _ = await (a, d, t)
    }
}
```

Each block of the screen binds to its own store's `phase`/`content`, so a slow or failing section never blocks the rest of the screen.

## Usage in a view

```swift
struct ProfileView: View {
    @State private var store: ProfileStore

    var body: some View {
        switch store.phase {
        case .idle, .loading:
            ProgressView()
        case .loaded:
            if let profile = store.content {
                ProfileContent(profile)
            }
        case .error:
            ErrorView(error: store.lastError) {
                Task { try? await store.load(force: true) }
            }
        }
    }
}
```
