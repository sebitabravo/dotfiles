---
name: mobile-app-testing
description: Mobile app testing strategies covering unit tests, integration tests, UI tests, snapshot tests, and CI pipelines for Android (Espresso) and iOS (XCTest).
---

## Android Testing

### Unit Tests (JUnit + MockK)

```kotlin
class UserViewModelTest {
    @get:Rule
    val dispatcherRule = StandardTestDispatcher()

    private val getUserUseCase = mockk<GetUserUseCase>()
    private val searchUseCase = mockk<SearchUsersUseCase>()

    @Test
    fun `load user success updates state`() = runTest {
        val user = User(id = "1", name = "Test", email = "test@test.com")
        coEvery { getUserUseCase("1") } returns Result.success(user)

        val viewModel = UserViewModel(getUserUseCase)
        viewModel.load("1")
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertIs<UserUiState.Success>(state)
        assertEquals("Test", state.user.name)
    }

    @Test
    fun `load user failure shows error`() = runTest {
        coEvery { getUserUseCase("1") } returns Result.failure(Exception("Not found"))

        val viewModel = UserViewModel(getUserUseCase)
        viewModel.load("1")
        advanceUntilIdle()

        assertIs<UserUiState.Error>(viewModel.uiState.value)
    }
}
```

### UI Tests (Compose Testing)

```kotlin
@RunWith(AndroidJUnit4::class)
class LoginScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun login_withValidCredentials_navigatesToDashboard() {
        composeRule.setContent {
            LoginScreen(onNavigateToDashboard = {}, viewModel = FakeLoginViewModel())
        }

        composeRule.onNodeWithText("Email").performTextInput("test@example.com")
        composeRule.onNodeWithText("Password").performTextInput("password123")
        composeRule.onNodeWithText("Sign in").performClick()

        // Verify state or navigation
    }

    @Test
    fun login_withEmptyEmail_showsValidationError() {
        composeRule.setContent {
            LoginScreen(onNavigateToDashboard = {}, viewModel = FakeLoginViewModel())
        }

        composeRule.onNodeWithText("Sign in").performClick()
        composeRule.onNodeWithText("Email is required").assertIsDisplayed()
    }
}
```

### Screenshot Testing (Roborazzi)

```kotlin
@RunWith(AndroidJUnit4::class)
class UserListScreenshotTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun userList_lightTheme() {
        composeRule.setContent {
            AppTheme(darkTheme = false) {
                UserListContent(users = testUsers)
            }
        }
        composeRule.onRoot().captureRoboImage("user_list_light")
    }

    @Test
    fun userList_darkTheme() {
        composeRule.setContent {
            AppTheme(darkTheme = true) {
                UserListContent(users = testUsers)
            }
        }
        composeRule.onRoot().captureRoboImage("user_list_dark")
    }
}
```

## iOS Testing

### Unit Tests (XCTest)

```swift
@testable import MyApp
import XCTest

final class UserViewModelTests: XCTestCase {
    var sut: UserViewModel!
    var mockService: MockUserService!

    override func setUp() {
        mockService = MockUserService()
        sut = UserViewModel(service: mockService)
    }

    override func tearDown() {
        sut = nil
        mockService = nil
    }

    @MainActor
    func testLoadUsersSuccess() async throws {
        let expectedUsers = [User(id: "1", name: "Test", email: "test@test.com")]
        mockService.usersToReturn = expectedUsers

        await sut.loadUsers()

        XCTAssertEqual(sut.users.count, 1)
        XCTAssertEqual(sut.users.first?.name, "Test")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    @MainActor
    func testLoadUsersFailure() async throws {
        mockService.errorToThrow = APIError.httpError(500)

        await sut.loadUsers()

        XCTAssertTrue(sut.users.isEmpty)
        XCTAssertNotNil(sut.error)
    }
}

// Mock
class MockUserService: UserServiceProtocol {
    var usersToReturn: [User] = []
    var errorToThrow: Error?

    func fetchUsers() async throws -> [User] {
        if let error = errorToThrow { throw error }
        return usersToReturn
    }
}
```

### UI Tests (XCUITest)

```swift
final class LoginUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testSuccessfulLogin() {
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        let loginButton = app.buttons["Sign in"]

        emailField.tap()
        emailField.typeText("test@example.com\n")

        passwordField.tap()
        passwordField.typeText("password123\n")

        loginButton.tap()

        let dashboardTitle = app.staticTexts["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))
    }
}
```

### Snapshot Testing (swift-snapshot-testing)

```swift
import SnapshotTesting

final class UserListSnapshotTests: XCTestCase {
    func testUserListLight() {
        let view = UserListView(users: User.samples)
        let controller = UIHostingController(rootView: view)
        assertSnapshot(of: controller, as: .image(on: .iPhone15))
    }

    func testUserListDark() {
        let view = UserListView(users: User.samples).preferredColorScheme(.dark)
        let controller = UIHostingController(rootView: view)
        assertSnapshot(of: controller, as: .image(on: .iPhone15))
    }
}
```

## CI Integration

### Android (GitHub Actions)

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 17 }
      - run: ./gradlew testDebugUnitTest
      - run: ./gradlew connectedDebugAndroidTest
        # Or use Firebase Test Lab for device testing
```

### iOS (GitHub Actions)

```yaml
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Rules

- Unit tests: mock external dependencies only. Real objects for everything else.
- UI tests: test user flows, not implementation.
- Screenshot tests: light + dark themes.
- `@MainActor` on all ViewModel tests in Swift.
- `runTest` + `advanceUntilIdle` for coroutine tests.
- `FakeXxx` implementations over mocks for complex dependencies.
- Test file mirrors source file path.
- CI pipeline: unit → integration → UI.
