---
name: dotnet-backend-patterns
description: C#/.NET backend patterns including ASP.NET Core minimal APIs, EF Core, Dapper, xUnit testing, middleware, and dependency injection.
---

## Project Structure

```
src/
├── MyApp.Api/              # Presentation layer
│   ├── Program.cs
│   ├── Endpoints/
│   └── Middleware/
├── MyApp.Application/      # Use cases / business logic
│   ├── Services/
│   ├── Commands/
│   └── Queries/
├── MyApp.Domain/           # Domain models, interfaces
│   ├── Entities/
│   ├── Interfaces/
│   └── Exceptions/
├── MyApp.Infrastructure/   # Data access, external services
│   ├── Persistence/
│   ├── Repositories/
│   └── Services/
└── MyApp.Tests/
    ├── Unit/
    └── Integration/
```

## Minimal APIs

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IUserService, UserService>();

var app = builder.Build();

app.MapGet("/api/v1/users", async (
    IUserService service,
    CancellationToken ct,
    int page = 1,
    int pageSize = 20
) => {
    var result = await service.ListAsync(page, pageSize, ct);
    return Results.Ok(result);
});

app.MapGet("/api/v1/users/{id:guid}", async (
    Guid id,
    IUserService service,
    CancellationToken ct
) => {
    var user = await service.GetByIdAsync(id, ct);
    return user is null ? Results.NotFound() : Results.Ok(user);
});

app.MapPost("/api/v1/users", async (
    CreateUserRequest request,
    IUserService service,
    CancellationToken ct
) => {
    var user = await service.CreateAsync(request, ct);
    return Results.Created($"/api/v1/users/{user.Id}", user);
});

app.Run();
```

## EF Core Patterns

### Entity Configuration

```csharp
public class User
{
    public Guid Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public ICollection<Order> Orders { get; set; } = [];
}

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("users");
        builder.HasKey(u => u.Id);
        builder.Property(u => u.Email).IsRequired().HasMaxLength(255);
        builder.HasIndex(u => u.Email).IsUnique();
        builder.Property(u => u.CreatedAt).HasDefaultValueSql("now()");
    }
}
```

### Repository

```csharp
public class UserRepository : IUserRepository
{
    private readonly AppDbContext _db;

    public UserRepository(AppDbContext db) => _db = db;

    public async Task<User?> GetByIdAsync(Guid id, CancellationToken ct) =>
        await _db.Users
            .Include(u => u.Orders)
            .FirstOrDefaultAsync(u => u.Id == id, ct);

    public async Task<PagedResult<User>> ListAsync(int page, int pageSize, CancellationToken ct)
    {
        var total = await _db.Users.CountAsync(ct);
        var items = await _db.Users
            .OrderByDescending(u => u.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);
        return new(items, total, page, pageSize);
    }

    public void Add(User user) => _db.Users.Add(user);
}
```

### Migration

```bash
dotnet ef migrations add AddUserTable
dotnet ef database update
dotnet ef migrations script --output migration.sql  # SQL script for review
```

## Dapper (Lightweight ORM)

```csharp
public class DapperUserRepository : IUserRepository
{
    private readonly IDbConnection _db;

    public DapperUserRepository(IDbConnection db) => _db = db;

    public async Task<User?> GetByIdAsync(Guid id, CancellationToken ct) =>
        await _db.QueryFirstOrDefaultAsync<User>(
            "SELECT * FROM users WHERE id = @Id",
            new { Id = id });

    public async Task<IReadOnlyList<User>> ListAsync(int page, int pageSize, CancellationToken ct) =>
        (await _db.QueryAsync<User>(
            "SELECT * FROM users ORDER BY created_at DESC LIMIT @Limit OFFSET @Offset",
            new { Limit = pageSize, Offset = (page - 1) * pageSize }))
        .AsList()
        .AsReadOnly();
}
```

## Dependency Injection

```csharp
// Scoped: per-request (DB contexts, repos)
builder.Services.AddScoped<IUserRepository, UserRepository>();

// Transient: always new instance
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();

// Singleton: single instance
builder.Services.AddSingleton<ICacheService, RedisCacheService>();

// Options pattern
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));

// Usage via constructor
public class UserService(IUserRepository repo, IOptions<JwtOptions> options)
{
    private readonly JwtOptions _jwt = options.Value;
}
```

## Middleware

```csharp
public class ExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionMiddleware> _log;

    public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> log)
    {
        _next = next;
        _log = log;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (NotFoundException ex)
        {
            _log.LogWarning(ex, "Not found: {Path}", context.Request.Path);
            await Results.Problem(ex.Message, statusCode: 404).ExecuteAsync(context);
        }
        catch (ValidationException ex)
        {
            await Results.ValidationProblem(ex.Errors).ExecuteAsync(context);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Unhandled exception");
            await Results.Problem("Internal server error", statusCode: 500).ExecuteAsync(context);
        }
    }
}
```

## xUnit Testing

```csharp
public class UserServiceTests
{
    private readonly IUserService _service;
    private readonly Mock<IUserRepository> _repoMock;

    public UserServiceTests()
    {
        _repoMock = new Mock<IUserRepository>();
        _service = new UserService(_repoMock.Object);
    }

    [Fact]
    public async Task GetById_ExistingUser_ReturnsUser()
    {
        var user = new User { Id = Guid.NewGuid(), Email = "test@example.com" };
        _repoMock.Setup(r => r.GetByIdAsync(user.Id, default))
                 .ReturnsAsync(user);

        var result = await _service.GetByIdAsync(user.Id);

        Assert.Equal(user.Email, result!.Email);
    }

    [Theory]
    [InlineData("")]
    [InlineData("invalid")]
    [InlineData(null)]
    public async Task Create_InvalidEmail_Throws(string? email)
    {
        await Assert.ThrowsAsync<ValidationException>(() =>
            _service.CreateAsync(new CreateUserRequest { Email = email!, Name = "Test" }));
    }
}
```

## Rules

- Minimal APIs over controllers for new projects.
- Repository pattern for data access. Never leak EF types to application layer.
- `IEntityTypeConfiguration` for fluent mapping.
- Options pattern for configuration.
- `CancellationToken` on every async method.
- Primary constructors (C# 12) for DI.
- `Results<T>` for typed HTTP responses.
- Test with mocks for units, real DB for integration.
