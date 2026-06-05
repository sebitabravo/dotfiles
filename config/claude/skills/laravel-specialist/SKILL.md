---
name: laravel-specialist
description: Laravel 11+ patterns including Eloquent ORM, Sanctum auth, API resources, queues with Horizon, event broadcasting, Livewire, and Pest testing.
---

## Project Structure

```
app/
├── Models/              # Eloquent models
├── Http/
│   ├── Controllers/     # Thin controllers
│   ├── Middleware/
│   ├── Requests/        # Form validation
│   └── Resources/       # API transformers
├── Services/            # Business logic
├── Repositories/        # Data access layer
├── Actions/             # Single-responsibility actions
├── Events/
├── Listeners/
├── Jobs/                # Queue jobs
├── Policies/            # Authorization
└── Rules/               # Custom validation rules
```

## Eloquent Patterns

### Model Setup

```php
// app/Models/User.php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class User extends Model
{
    use SoftDeletes, HasFactory;

    protected $fillable = ['name', 'email'];
    protected $hidden = ['password'];
    protected $casts = [
        'email_verified_at' => 'datetime',
        'settings' => 'array',
    ];

    public function posts(): HasMany
    {
        return $this->hasMany(Post::class);
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }
}
```

### Eager Loading (Prevent N+1)

```php
// BAD: N+1
$users = User::all();
foreach ($users as $user) {
    echo $user->posts->count();
}

// GOOD: Eager load
$users = User::with('posts', 'posts.tags')->get();

// GOOD: Lazy eager load when conditional
$users = User::all();
$users->load('posts');
```

### API Resources

```php
// app/Http/Resources/UserResource.php
namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'posts_count' => $this->whenCounted('posts'),
            'posts' => PostResource::collection($this->whenLoaded('posts')),
            'created_at' => $this->created_at->toISOString(),
            'links' => [
                'self' => route('users.show', $this->id),
            ],
        ];
    }
}

// Controller
return UserResource::collection(User::with('posts')->paginate(15));
```

## Form Requests

```php
// app/Http/Requests/StoreUserRequest.php
namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreUserRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ];
    }
}

// Controller
public function store(StoreUserRequest $request)
{
    $user = User::create($request->validated());
    return new UserResource($user);
}
```

## Actions (Single Responsibility)

```php
// app/Actions/CreateUserAction.php
namespace App\Actions;

use App\Models\User;
use App\Services\EmailService;

class CreateUserAction
{
    public function __construct(
        private EmailService $email,
    ) {}

    public function execute(array $data): User
    {
        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => bcrypt($data['password']),
        ]);

        $this->email->sendWelcome($user);

        return $user;
    }
}
```

## Sanctum Auth

```php
// Login
$token = $user->createToken('auth-token')->plainTextToken;

// Routes
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', fn(Request $request) => $request->user());
    Route::apiResource('posts', PostController::class);
});

// Abilities
$token = $user->createToken('admin-token', ['post:create', 'post:delete'])->plainTextToken;

// Middleware check
if ($request->user()->tokenCan('post:create')) { ... }
```

## Queues with Horizon

```php
// app/Jobs/ProcessPayment.php
namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Queue\InteractsWithQueue;

class ProcessPayment implements ShouldQueue
{
    use InteractsWithQueue, Queueable;

    public int $tries = 3;
    public int $backoff = 30;

    public function __construct(
        public int $paymentId,
    ) {}

    public function handle(PaymentService $payments): void
    {
        $payments->process($this->paymentId);
    }

    public function failed(\Throwable $exception): void
    {
        // Handle failure
    }
}

// Dispatch
ProcessPayment::dispatch($payment->id)->onQueue('payments');
```

## Pest Testing

```php
// tests/Feature/UserTest.php
use App\Models\User;
use function Pest\Laravel\{post, get, actingAs};

describe('User Registration', function () {
    it('creates user with valid data', function () {
        $response = post('/api/register', [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertCreated();
        expect(User::where('email', 'test@example.com')->exists())->toBeTrue();
    });

    it('rejects duplicate email', function () {
        User::factory()->create(['email' => 'test@example.com']);

        post('/api/register', [
            'name' => 'Duplicate',
            'email' => 'test@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])->assertStatus(409);
    });
});
```

## Rules

- Thin controllers. Logic in Actions or Services.
- Form Requests for validation. Never validate in controllers.
- API Resources for response transformation.
- Eager load relationships. Detect N+1 with `DB::listen`.
- Queues for anything >100ms (emails, notifications, reports).
- Policies for authorization. Never check roles directly.
- Pest over PHPUnit for readability.
- `phpstan analyse` for static analysis.
