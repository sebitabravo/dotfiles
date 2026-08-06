---
name: android-clean-architecture
description: >
  Android Clean Architecture with MVVM, use cases, repository pattern, dependency injection with Hilt, and layered module structure.
  Use when structuring an Android app into layers, writing use cases or repositories, wiring Hilt, or reviewing Android module boundaries.
---

## Module Structure

```
app/
├── di/                         # Hilt modules
├── navigation/
data/
├── remote/
│   ├── api/                    # Retrofit interfaces
│   ├── dto/                    # Network models
│   └── mapper/                 # DTO → Entity mappers
├── local/
│   ├── dao/                    # Room DAOs
│   ├── entity/                 # DB entities
│   └── mapper/
├── repository/                 # Repository implementations
domain/
├── model/                      # Domain models
├── repository/                 # Repository interfaces
├── usecase/                    # Use cases
feature/
├── login/
│   ├── LoginScreen.kt
│   ├── LoginViewModel.kt
│   └── LoginUiState.kt
├── dashboard/
└── settings/
```

## Domain Layer

### Model

```kotlin
data class User(
    val id: String,
    val email: String,
    val name: String,
    val avatarUrl: String?,
)
```

### Repository Interface

```kotlin
interface UserRepository {
    suspend fun getById(id: String): Result<User>
    suspend fun search(query: String, page: Int): Result<PagedResult<User>>
    suspend fun save(user: User): Result<User>
}
```

### Use Case

```kotlin
class GetUserUseCase @Inject constructor(
    private val repository: UserRepository,
) {
    suspend operator fun invoke(id: String): Result<User> =
        repository.getById(id)
}

class SearchUsersUseCase @Inject constructor(
    private val repository: UserRepository,
) {
    suspend operator fun invoke(query: String, page: Int = 1): Result<PagedResult<User>> {
        if (query.isBlank()) return Result.failure(ValidationException("Query cannot be empty"))
        return repository.search(query.trim(), page)
    }
}
```

## Data Layer

### API (Retrofit)

```kotlin
interface UserApi {
    @GET("users/{id}")
    suspend fun getUser(@Path("id") id: String): UserDto

    @GET("users")
    suspend fun searchUsers(
        @Query("q") query: String,
        @Query("page") page: Int,
        @Query("per_page") perPage: Int = 20,
    ): PagedResponse<UserDto>
}

@Serializable
data class UserDto(
    @SerialName("id") val id: String,
    @SerialName("email") val email: String,
    @SerialName("name") val name: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
)

fun UserDto.toDomain() = User(id = id, email = email, name = name, avatarUrl = avatarUrl)
```

### Repository Implementation

```kotlin
class UserRepositoryImpl @Inject constructor(
    private val api: UserApi,
    private val dao: UserDao,
) : UserRepository {

    override suspend fun getById(id: String): Result<User> = runCatching {
        // Cache-first strategy
        dao.getById(id)?.toDomain() ?: api.getUser(id).also {
            dao.insert(it.toEntity())
        }.toDomain()
    }

    override suspend fun search(query: String, page: Int): Result<PagedResult<User>> = runCatching {
        val response = api.searchUsers(query, page)
        response.items.map { it.toDomain() }.let {
            PagedResult(items = it, total = response.total, page = page)
        }
    }
}
```

## DI with Hilt

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DataModule {
    @Provides
    fun provideUserApi(retrofit: Retrofit): UserApi =
        retrofit.create(UserApi::class.java)
}

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository
}

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit =
        Retrofit.Builder()
            .baseUrl("https://api.example.com/v1/")
            .client(okHttpClient)
            .addConverterFactory(Json.asConverterFactory("application/json".toMediaType()))
            .build()
}
```

## Presentation Layer (MVVM)

```kotlin
@HiltViewModel
class UserDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val getUserUseCase: GetUserUseCase,
) : ViewModel() {

    private val userId: String = savedStateHandle["userId"]!!
    private val _uiState = MutableStateFlow<UserDetailUiState>(UserDetailUiState.Loading)
    val uiState: StateFlow<UserDetailUiState> = _uiState.asStateFlow()

    init { loadUser() }

    fun loadUser() {
        viewModelScope.launch {
            _uiState.value = UserDetailUiState.Loading
            getUserUseCase(userId)
                .onSuccess { _uiState.value = UserDetailUiState.Success(it) }
                .onFailure { _uiState.value = UserDetailUiState.Error(it.message ?: "Unknown error") }
        }
    }
}

sealed interface UserDetailUiState {
    data object Loading : UserDetailUiState
    data class Success(val user: User) : UserDetailUiState
    data class Error(val message: String) : UserDetailUiState
}
```

## Rules

- Domain layer has ZERO Android dependencies (pure Kotlin).
- Use cases = single responsibility. One public method.
- Repository interface in domain, implementation in data.
- `Result<T>` for error propagation. No exceptions in use cases.
- `sealed interface` for UI state (Loading/Success/Error).
- Hilt for DI. Constructor injection preferred over field injection.
- Mappers: DTO ↔ Entity ↔ Domain. No layer leaking.
- Cache strategy in repository, not in ViewModel.
