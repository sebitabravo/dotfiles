---
name: swift
description: >
  iOS/macOS development with Swift, SwiftUI, SwiftData, async/await, Actors, and modern Apple platform patterns.
  Use when writing or reviewing Swift for iOS/macOS: SwiftUI views, SwiftData models, async/await, or Actor isolation and concurrency warnings.
---

## SwiftUI Architecture

### State Management

```swift
// Observable (Swift Observation, iOS 17+)
@Observable
final class UserViewModel {
    var users: [User] = []
    var isLoading = false
    var error: String?

    private let service: UserService

    init(service: UserService = .shared) {
        self.service = service
    }

    @MainActor
    func loadUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            users = try await service.fetchUsers()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// View
struct UserListView: View {
    @State private var viewModel = UserViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                ErrorView(message: error, onRetry: { Task { await viewModel.loadUsers() } })
            } else {
                List(viewModel.users) { user in
                    UserRow(user: user)
                }
            }
        }
        .task { await viewModel.loadUsers() }
    }
}
```

### Navigation (iOS 18+)

```swift
@Observable
final class AppRouter {
    var path = NavigationPath()
    var selectedTab: Tab = .users

    enum Tab { case users, settings }

    func push(_ route: Route) { path.append(route) }
    func pop() { path.removeLast() }
    func popToRoot() { path.removeLast(path.count) }
}

enum Route: Hashable {
    case userDetail(id: String)
    case userEdit(id: String)
    case settings
}

struct AppView: View {
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: Binding(
            get: { router.selectedTab },
            set: { router.selectedTab = $0 }
        )) {
            NavigationStack(path: $router.path) {
                UserListView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .userDetail(let id): UserDetailView(userId: id)
                        case .userEdit(let id): UserEditView(userId: id)
                        case .settings: SettingsView()
                        }
                    }
            }
            .tabItem { Label("Users", systemImage: "person.2") }
            .tag(AppRouter.Tab.users)
        }
        .environment(router)
    }
}
```

### SwiftData

```swift
@Model
final class User {
    #Unique<([String])>([\.email])

    var name: String
    var email: String
    var createdAt: Date = .now

    @Relationship(deleteRule: .cascade, inverse: \Post.author)
    var posts: [Post] = []

    init(name: String, email: String) {
        self.name = name
        self.email = email
    }
}

// Query
struct UserListView: View {
    @Query(sort: \User.createdAt, order: .reverse)
    private var users: [User]

    @Environment(\.modelContext) private var context

    var body: some View {
        List(users) { user in
            VStack(alignment: .leading) {
                Text(user.name).font(.headline)
                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
```

### Networking with async/await

```swift
actor APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://api.example.com/v1")!

    func request<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// Usage
let users: [UserDTO] = try await APIClient.shared.request("users")
```

### Concurrency Patterns

```swift
// Task Group — parallel fetching
func loadDashboard() async throws -> Dashboard {
    try await withThrowingTaskGroup(of: (any Sendable).self) { group in
        group.addTask { try await fetchUsers() as [User] }
        group.addTask { try await fetchStats() as Stats }
        group.addTask { try await fetchNotifications() as [Notification] }

        var users: [User]?
        var stats: Stats?
        var notifications: [Notification]?

        for try await result in group {
            switch result {
            case let u as [User]: users = u
            case let s as Stats: stats = s
            case let n as [Notification]: notifications = n
            default: break
            }
        }

        return Dashboard(
            users: users ?? [],
            stats: stats ?? Stats(),
            notifications: notifications ?? []
        )
    }
}
```

## Preview

```swift
#Preview {
    NavigationStack {
        UserListView()
            .modelContainer(for: User.self, inMemory: true)
    }
}
```

## Rules

- `@Observable` (Swift Observation) over `ObservableObject`.
- `@State` for view-owned state, `@Environment` for shared.
- `actor` for shared mutable state (thread safety).
- `async/await` over completion handlers.
- SwiftData over Core Data for new projects.
- NavigationSplitView for iPad/macOS, NavigationStack for iPhone.
- `#Preview` macros for all views.
- `Sendable` conformance for types crossing concurrency boundaries.
