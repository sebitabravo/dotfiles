---
name: golang-pro
description: Go concurrency patterns, goroutines, channels, gRPC service definitions, microservices architecture, and production best practices.
---

## Project Structure

```
service/
├── cmd/
│   └── server/
│       └── main.go           # Entry point
├── internal/
│   ├── handler/              # HTTP/gRPC handlers
│   ├── service/              # Business logic
│   ├── repository/           # Data access
│   ├── model/                # Domain models
│   └── config/               # Configuration
├── pkg/                      # Public reusable packages
├── api/
│   └── proto/                # Protobuf definitions
├── migrations/
├── go.mod
└── go.sum
```

## Concurrency Patterns

### Worker Pool

```go
func processItems(ctx context.Context, items []Item) error {
    const maxWorkers = 10

    g, ctx := errgroup.WithContext(ctx)
    itemsCh := make(chan Item)

    // Producer
    g.Go(func() error {
        defer close(itemsCh)
        for _, item := range items {
            select {
            case <-ctx.Done():
                return ctx.Err()
            case itemsCh <- item:
            }
        }
        return nil
    })

    // Workers
    for i := 0; i < maxWorkers; i++ {
        g.Go(func() error {
            for item := range itemsCh {
                if err := process(ctx, item); err != nil {
                    return err
                }
            }
            return nil
        })
    }

    return g.Wait()
}
```

### Fan-Out/Fan-In

```go
func fanOutFanIn(ctx context.Context, input <-chan Data, workers int) <-chan Result {
    results := make(chan Result)
    var wg sync.WaitGroup

    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for data := range input {
                select {
                case <-ctx.Done():
                    return
                case results <- transform(data):
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

### Rate Limiter

```go
type RateLimiter struct {
    ticker *time.Ticker
    tokens chan struct{}
}

func NewRateLimiter(rps int) *RateLimiter {
    rl := &RateLimiter{
        ticker: time.NewTicker(time.Second / time.Duration(rps)),
        tokens: make(chan struct{}, rps),
    }
    go func() {
        for range rl.ticker.C {
            select {
            case rl.tokens <- struct{}{}:
            default:
            }
        }
    }()
    return rl
}

func (rl *RateLimiter) Wait(ctx context.Context) error {
    select {
    case <-ctx.Done():
        return ctx.Err()
    case <-rl.tokens:
        return nil
    }
}
```

### Context Propagation

```go
func (s *Service) HandleRequest(ctx context.Context, req *Request) (*Response, error) {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    // Propagate trace ID
    ctx = context.WithValue(ctx, traceKey{}, req.TraceID)

    result, err := s.repo.Get(ctx, req.ID)
    if err != nil {
        return nil, fmt.Errorf("get %s: %w", req.ID, err)
    }

    return &Response{Data: result}, nil
}
```

## gRPC

### Proto Definition

```protobuf
syntax = "proto3";
package users.v1;

service UserService {
    rpc GetUser(GetUserRequest) returns (GetUserResponse);
    rpc ListUsers(ListUsersRequest) returns (stream ListUsersResponse);
    rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
}

message GetUserRequest {
    string id = 1;
}

message GetUserResponse {
    User user = 1;
}

message User {
    string id = 1;
    string email = 2;
    string name = 3;
}
```

### Server Implementation

```go
type UserServer struct {
    pb.UnimplementedUserServiceServer
    service *UserService
}

func (s *UserServer) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.GetUserResponse, error) {
    user, err := s.service.GetByID(ctx, req.Id)
    if err != nil {
        if errors.Is(err, ErrNotFound) {
            return nil, status.Errorf(codes.NotFound, "user %s not found", req.Id)
        }
        return nil, status.Errorf(codes.Internal, "failed to get user")
    }

    return &pb.GetUserResponse{
        User: &pb.User{
            Id:    user.ID,
            Email: user.Email,
            Name:  user.Name,
        },
    }, nil
}
```

### Client with Retry

```go
func NewGRPCClient(addr string) (pb.UserServiceClient, error) {
    conn, err := grpc.Dial(addr,
        grpc.WithTransportCredentials(insecure.NewCredentials()),
        grpc.WithDefaultServiceConfig(`{
            "methodConfig": [{
                "name": [{"service": "users.v1.UserService"}],
                "retryPolicy": {
                    "maxAttempts": 3,
                    "initialBackoff": "0.1s",
                    "maxBackoff": "1s",
                    "backoffMultiplier": 2,
                    "retryableStatusCodes": ["UNAVAILABLE", "DEADLINE_EXCEEDED"]
                }
            }]
        }`),
    )
    if err != nil {
        return nil, fmt.Errorf("dial: %w", err)
    }
    return pb.NewUserServiceClient(conn), nil
}
```

## HTTP Server

```go
func NewServer(handler *Handler) *http.Server {
    mux := http.NewServeMux()
    mux.HandleFunc("GET /api/v1/users/{id}", handler.GetUser)
    mux.HandleFunc("POST /api/v1/users", handler.CreateUser)

    return &http.Server{
        Addr:         ":8080",
        Handler:      middleware.Chain(mux,
            middleware.RequestID(),
            middleware.Logger(),
            middleware.Recover(),
            middleware.CORS(allowedOrigins),
        ),
        ReadTimeout:  5 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  120 * time.Second,
    }
}
```

## Error Handling

```go
// Sentinel errors
var (
    ErrNotFound   = errors.New("not found")
    ErrConflict   = errors.New("conflict")
    ErrValidation = errors.New("validation error")
)

// Wrap with context
if err != nil {
    return fmt.Errorf("service.CreateUser: %w", err)
}

// Check with errors.Is / errors.As
if errors.Is(err, ErrNotFound) { ... }
```

## Rules

- `errgroup` for concurrent goroutine management.
- Always propagate `context.Context` as first parameter.
- `close(ch)` in producer, never in consumer.
- `fmt.Errorf("function: %w", err)` for error wrapping.
- Sentinel errors with `errors.Is`/`errors.As`.
- `sync.WaitGroup` or `errgroup` — never bare goroutines in production.
- Buffer channels to decouple producer/consumer.
- Timeouts on every external call via context.
- Interfaces defined by consumers, not producers.
