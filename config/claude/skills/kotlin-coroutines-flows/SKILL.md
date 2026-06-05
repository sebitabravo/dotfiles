---
name: kotlin-coroutines-flows
description: Kotlin coroutines and Flow patterns including structured concurrency, channels, shared flows, state flows, and error handling.
---

## Coroutine Basics

### Structured Concurrency

```kotlin
class UserRepository @Inject constructor(
    private val api: UserApi,
    private val dao: UserDao,
) {
    // viewModelScope provides structured scope
    // No GlobalScope, ever
    suspend fun getUser(id: String): User = coroutineScope {
        val userDeferred = async { api.fetchUser(id) }
        val postsDeferred = async { api.fetchPosts(id) }

        val user = userDeferred.await()
        val posts = postsDeferred.await()

        user.copy(posts = posts)
    }
}
```

### Error Handling

```kotlin
// Result-based (preferred)
suspend fun safeFetch(): Result<User> = runCatching {
    api.fetchUser(userId)
}

// Try-catch for specific handling
suspend fun fetchWithRetry(maxRetries: Int = 3): User {
    repeat(maxRetries) { attempt ->
        try {
            return api.fetchUser(userId)
        } catch (e: HttpException) {
            if (attempt == maxRetries - 1) throw e
            delay(2.0.pow(attempt) * 1000) // Exponential backoff
        }
    }
    error("Unreachable")
}
```

### SupervisorJob

```kotlin
// Children fail independently
val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

scope.launch {
    // If this fails, the sibling below still runs
    updateUser()
}
scope.launch {
    // Independent operation
    sendNotification()
}
```

## Flow Patterns

### Creating Flows

```kotlin
// From suspend function
fun getUsers(): Flow<List<User>> = flow {
    emit(api.fetchUsers())
}

// With retry + caching
fun getUsers(): Flow<Result<List<User>>> = flow {
    emit(Result.success(api.fetchUsers()))
}.retry(3) { it is IOException }
  .catch { emit(Result.failure(it)) }
  .flowOn(Dispatchers.IO)
```

### StateFlow (State Holder)

```kotlin
class UserViewModel @Inject constructor(
    private val getUserUseCase: GetUserUseCase,
) : ViewModel() {

    private val _uiState = MutableStateFlow<UserUiState>(UserUiState.Loading)
    val uiState: StateFlow<UserUiState> = _uiState.asStateFlow()

    fun load(id: String) {
        viewModelScope.launch {
            getUserUseCase(id)
                .onSuccess { _uiState.value = UserUiState.Success(it) }
                .onFailure { _uiState.value = UserUiState.Error(it.message) }
        }
    }
}

sealed interface UserUiState {
    data object Loading : UserUiState
    data class Success(val user: User) : UserUiState
    data class Error(val message: String?) : UserUiState
}
```

### SharedFlow (Events)

```kotlin
// One-shot events (navigation, snackbar, etc.)
class LoginViewModel : ViewModel() {
    private val _events = MutableSharedFlow<LoginEvent>()
    val events: SharedFlow<LoginEvent> = _events.asSharedFlow()

    fun login() {
        viewModelScope.launch {
            val result = loginUseCase(params)
            if (result.isSuccess) {
                _events.emit(LoginEvent.NavigateToDashboard(result.getOrThrow().userId))
            } else {
                _events.emit(LoginEvent.ShowError(result.exceptionOrNull()?.message))
            }
        }
    }
}

sealed interface LoginEvent {
    data class NavigateToDashboard(val userId: String) : LoginEvent
    data class ShowError(val message: String?) : LoginEvent
}

// Collection in UI
LaunchedEffect(Unit) {
    viewModel.events.collect { event ->
        when (event) {
            is LoginEvent.NavigateToDashboard -> navController.navigate(...)
            is LoginEvent.ShowError -> snackbarHostState.showSnackbar(event.message ?: "Error")
        }
    }
}
```

### Combining Flows

```kotlin
// Combine two flows
val dashboard: Flow<DashboardState> = combine(
    userRepository.observeUser(userId),
    orderRepository.observeOrders(userId),
    ::DashboardState,
)

// Zip (wait for both to emit)
val profileData: Flow<Profile> = userFlow.zip(postsFlow) { user, posts ->
    Profile(user = user, posts = posts)
}
```

### Flow Operators

```kotlin
fun searchUsers(query: Flow<String>): Flow<List<User>> = query
    .debounce(300)
    .filter { it.length >= 2 }
    .distinctUntilChanged()
    .flatMapLatest { query ->
        userRepository.search(query)
    }
    .catch { emit(emptyList()) }
```

### Channel (Hot Stream)

```kotlin
// Producer-consumer with buffer
fun observeSyncEvents(): Flow<SyncEvent> = channelFlow {
    val listener = object : SyncListener {
        override fun onEvent(event: SyncEvent) {
            trySend(event)
        }
    }
    syncManager.addListener(listener)
    awaitClose { syncManager.removeListener(listener) }
}
```

## Testing Coroutines

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class UserViewModelTest {
    @get:Rule
    val dispatcherRule = StandardTestDispatcher()

    @Test
    fun load_success_updatesStateToSuccess() = runTest {
        val viewModel = UserViewModel(FakeGetUserUseCase(UserFactory.create()))

        viewModel.load("user-1")
        advanceUntilIdle()

        assertEquals(UserUiState::class, viewModel.uiState.value::class)
    }

    @Test
    fun search_debouncesRapidQueries() = runTest {
        val queries = MutableStateFlow("")
        val results = mutableListOf<List<User>>()

        val job = launch {
            searchUsers(queries).toList(results)
        }

        queries.value = "a"
        queries.value = "ab"
        queries.value = "abc"
        advanceTimeBy(400)

        assertEquals(1, results.size) // Only the final query emitted
        job.cancel()
    }
}
```

## Rules

- `viewModelScope` for ViewModels, `lifecycleScope` for Activities/Fragments. Never `GlobalScope`.
- `StateFlow` for state. `SharedFlow` for events.
- `runCatching` for Result-based error handling.
- `SupervisorJob` when children should fail independently.
- `debounce` + `distinctUntilChanged` for search flows.
- `flatMapLatest` over `flatMapMerge` for cancel-previous semantics.
- `flowOn(Dispatchers.IO)` once, not on every operator.
- Test with `StandardTestDispatcher` and `runTest`.
