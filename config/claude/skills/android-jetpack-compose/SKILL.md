---
name: android-jetpack-compose
description: >
  Android development with Jetpack Compose including state management, navigation, Material 3, side effects, and Compose architecture patterns.
  Use when writing or reviewing Compose UI: composables, state hoisting, navigation, Material 3 theming, or side effects (LaunchedEffect, DisposableEffect).
---

## Compose State

### State Hoisting

```kotlin
@Composable
fun EmailField(
    email: String,
    onEmailChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    isError: Boolean = false,
) {
    OutlinedTextField(
        value = email,
        onValueChange = onEmailChange,
        label = { Text("Email") },
        isError = isError,
        modifier = modifier.fillMaxWidth(),
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
    )
}

// Usage — state hoisted to parent
@Composable
fun LoginScreen(viewModel: LoginViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    EmailField(
        email = uiState.email,
        onEmailChange = viewModel::onEmailChange,
        isError = uiState.emailError != null,
    )
}
```

### ViewModel + StateFlow

```kotlin
data class LoginUiState(
    val email: String = "",
    val password: String = "",
    val emailError: String? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val isSuccess: Boolean = false,
)

class LoginViewModel @Inject constructor(
    private val loginUseCase: LoginUseCase,
) : ViewModel() {
    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    fun onEmailChange(email: String) {
        _uiState.update { it.copy(email = email, emailError = null) }
    }

    fun onLogin() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            loginUseCase(LoginParams(_uiState.value.email, _uiState.value.password))
                .onSuccess { _uiState.update { it.copy(isLoading = false, isSuccess = true) } }
                .onFailure { _uiState.update { it.copy(isLoading = false, error = it.error) } }
        }
    }
}
```

## Navigation

```kotlin
// Type-safe navigation (2.8+)
@Serializable data object LoginRoute
@Serializable data class DashboardRoute(val userId: String)

@Composable
fun AppNavHost(navController: NavHostController) {
    NavHost(navController, startDestination = LoginRoute) {
        composable<LoginRoute> {
            LoginScreen(onLogin = { userId ->
                navController.navigate(DashboardRoute(userId)) {
                    popUpTo<LoginRoute> { inclusive = true }
                }
            })
        }
        composable<DashboardRoute> { backStackEntry ->
            val route = backStackEntry.toRoute<DashboardRoute>()
            DashboardScreen(userId = route.userId)
        }
    }
}
```

## Side Effects

```kotlin
@Composable
fun LoginScreen(viewModel: LoginViewModel = viewModel(), onNavigateToDashboard: () -> Unit) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    // Single-shot events
    LaunchedEffect(uiState.isSuccess) {
        if (uiState.isSuccess) onNavigateToDashboard()
    }

    // Show snackbar on error
    val snackbarHostState = remember { SnackbarHostState() }
    uiState.error?.let { error ->
        LaunchedEffect(error) {
            snackbarHostState.showSnackbar(error)
            viewModel.clearError()
        }
    }
}
```

## Lists (LazyColumn)

```kotlin
@Composable
fun UserList(users: List<User>, onUserClick: (String) -> Unit) {
    LazyColumn(
        contentPadding = PaddingValues(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        items(
            items = users,
            key = { it.id },
        ) { user ->
            UserRow(
                user = user,
                onClick = { onUserClick(user.id) },
                modifier = Modifier.animateItem(),
            )
        }
    }
}
```

## Material 3 Theming

```kotlin
// dynamicColor = true for Material You (Android 12+)
MaterialTheme(
    colorScheme = if (dynamicColor) dynamicColorScheme else lightColorScheme,
    typography = AppTypography,
) {
    content()
}
```

## Preview

```kotlin
@Preview(showBackground = true)
@Composable
private fun LoginScreenPreview() {
    AppTheme {
        LoginScreenContent(
            uiState = LoginUiState(email = "test@example.com"),
            onEmailChange = {},
            onPasswordChange = {},
            onLogin = {},
        )
    }
}
```

## Rules

- Stateless composables + state hoisting.
- `collectAsStateWithLifecycle()` (not `collectAsState`).
- `MutableStateFlow` + `StateFlow` in ViewModel. No `MutableState` in ViewModel.
- `key` parameter in LazyColumn items for stable identity.
- Single-shot events via `LaunchedEffect`, not state.
- `Modifier` as first optional parameter.
- Preview every composable.
- `viewModelScope.launch` for coroutines in ViewModel.
