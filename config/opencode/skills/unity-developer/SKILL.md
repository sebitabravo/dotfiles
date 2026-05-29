---
name: unity-developer
description: Unity 6 LTS development with URP/HDRP, C# scripting patterns, performance optimization, addressables, and production best practices.
---

## Project Structure

```
Assets/
├── Scripts/
│   ├── Core/              # GameManager, Singleton, Events
│   ├── Player/            # Player controller, input
│   ├── Enemies/           # AI, state machines
│   ├── UI/                # Screens, HUD, popups
│   ├── Audio/
│   ├── Data/              # ScriptableObjects, configs
│   └── Utilities/         # Extensions, helpers
├── Prefabs/
├── ScriptableObjects/
├── Addressables/
│   ├── Characters/
│   ├── Environments/
│   └── UI/
├── Scenes/
├── Materials/
├── Textures/
├── Models/
└── Audio/
```

## Architecture Patterns

### State Machine

```csharp
public interface IState
{
    void Enter();
    void Update();
    void Exit();
}

public class StateMachine
{
    private IState _currentState;

    public void ChangeState(IState newState)
    {
        _currentState?.Exit();
        _currentState = newState;
        _currentState.Enter();
    }

    public void Update() => _currentState?.Update();
}

// Usage
public class EnemyPatrolState : IState { ... }
public class EnemyChaseState : IState { ... }
public class EnemyAttackState : IState { ... }
```

### ScriptableObject Config

```csharp
[CreateAssetMenu(fileName = "EnemyConfig", menuName = "Config/Enemy")]
public class EnemyConfig : ScriptableObject
{
    public float moveSpeed = 3f;
    public float detectionRange = 10f;
    public float attackRange = 2f;
    public float attackCooldown = 1.5f;
    public int maxHealth = 100;
    public GameObject prefab;
}

// Reference in inspector or load via Addressables
public class Enemy : MonoBehaviour
{
    [SerializeField] private EnemyConfig _config;

    private void Start()
    {
        _health = _config.maxHealth;
        _navMeshAgent.speed = _config.moveSpeed;
    }
}
```

### Observer Pattern (Events)

```csharp
public static class GameEvents
{
    public static event Action<int> OnScoreChanged;
    public static event Action OnPlayerDied;
    public static event Action<Enemy> OnEnemyKilled;

    public static void ScoreChanged(int score) => OnScoreChanged?.Invoke(score);
    public static void PlayerDied() => OnPlayerDied?.Invoke();
    public static void EnemyKilled(Enemy enemy) => OnEnemyKilled?.Invoke(enemy);
}

// Subscriber
public class UIManager : MonoBehaviour
{
    [SerializeField] private TMP_Text _scoreText;

    private void OnEnable() => GameEvents.OnScoreChanged += UpdateScore;
    private void OnDisable() => GameEvents.OnScoreChanged -= UpdateScore;

    private void UpdateScore(int score) => _scoreText.text = score.ToString();
}
```

### Object Pooling

```csharp
public class ObjectPool : MonoBehaviour
{
    [SerializeField] private GameObject _prefab;
    [SerializeField] private int _initialSize = 10;

    private readonly Queue<GameObject> _pool = new();

    private void Start()
    {
        for (int i = 0; i < _initialSize; i++)
        {
            var obj = Instantiate(_prefab, transform);
            obj.SetActive(false);
            _pool.Enqueue(obj);
        }
    }

    public GameObject Get(Vector3 position, Quaternion rotation)
    {
        var obj = _pool.Count > 0 ? _pool.Dequeue() : Instantiate(_prefab, transform);
        obj.transform.SetPositionAndRotation(position, rotation);
        obj.SetActive(true);
        return obj;
    }

    public void Return(GameObject obj)
    {
        obj.SetActive(false);
        _pool.Enqueue(obj);
    }
}
```

## Input System (New)

```csharp
public class PlayerInput : MonoBehaviour
{
    private InputActions _actions;

    public Vector2 Move { get; private set; }
    public bool JumpPressed { get; private set; }

    private void Awake()
    {
        _actions = new InputActions();
    }

    private void OnEnable()
    {
        _actions.Enable();
        _actions.Player.Move.performed += ctx => Move = ctx.ReadValue<Vector2>();
        _actions.Player.Move.canceled += _ => Move = Vector2.zero;
        _actions.Player.Jump.performed += _ => JumpPressed = true;
    }

    private void LateUpdate() => JumpPressed = false;
}
```

## Addressables

```csharp
// Load single asset
var handle = Addressables.LoadAssetAsync<GameObject>("Enemy_Prefab");
await handle.Task;
var prefab = handle.Result;

// Instantiate
var instance = Instantiate(prefab, position, rotation);

// Load scene
await Addressables.LoadSceneAsync("GameScene", LoadSceneMode.Additive).Task;

// Cleanup
Addressables.Release(handle);
```

## Performance Tips

- Object pooling for frequently instantiated objects (bullets, enemies).
- `Object.Instantiate` is expensive. Pool instead.
- Profile with the Profiler + Frame Debugger.
- Use `Canvas.willRenderCanvases` sparingly — mark UI elements dirty only when changed.
- `SpriteAtlas` for 2D batching.
- LOD groups for 3D models.
- `Texture2D.Compress` for mobile.
- Avoid `GetComponent` in Update. Cache in Awake.
- `struct` over `class` for small data (no GC pressure).
- `Span<T>` and `MemoryMarshal` for array operations.

## Rules

- ScriptableObject for configuration data. Hard-coded = debt.
- Event-driven architecture. No direct references between systems.
- Object pooling for anything spawned frequently.
- New Input System over legacy.
- Profile before optimizing. The Profiler doesn't lie.
- Addressables for asset management in production.
- Separate logic from MonoBehaviour when possible (testability).
- Cache component references in Awake, not per-frame.
