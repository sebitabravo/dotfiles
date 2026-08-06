---
name: python-design-patterns
description: >
  Python design patterns, SOLID principles, composition over inheritance, dependency injection, and idiomatic Python architecture.
  Use when designing or refactoring Python architecture: choosing composition over inheritance, applying SOLID, wiring dependency injection, or splitting an overloaded class.
---

## SOLID in Python

### Single Responsibility

```python
# BAD: God class
class UserManager:
    def create_user(self, data): ...
    def send_email(self, user): ...
    def generate_report(self, user): ...

# GOOD: Separated concerns
class UserRepository:
    def create(self, data: UserCreate) -> User: ...

class EmailService:
    def send_welcome(self, user: User) -> None: ...

class ReportGenerator:
    def generate(self, user: User) -> Report: ...
```

### Dependency Inversion

```python
from abc import ABC, abstractmethod

class NotificationSender(ABC):
    @abstractmethod
    def send(self, recipient: str, message: str) -> None: ...

class EmailSender(NotificationSender):
    def send(self, recipient: str, message: str) -> None:
        # SMTP logic

class SlackSender(NotificationSender):
    def send(self, recipient: str, message: str) -> None:
        # Slack API logic

class NotificationService:
    def __init__(self, sender: NotificationSender):
        self._sender = sender

    def notify(self, recipient: str, message: str) -> None:
        self._sender.send(recipient, message)
```

## Patterns

### Repository Pattern

```python
from dataclasses import dataclass
from typing import Protocol

@dataclass
class User:
    id: int
    email: str
    name: str

class UserRepository(Protocol):
    async def get_by_id(self, id: int) -> User | None: ...
    async def get_by_email(self, email: str) -> User | None: ...
    async def create(self, data: dict) -> User: ...
    async def update(self, id: int, data: dict) -> User: ...
    async def delete(self, id: int) -> None: ...

class PostgresUserRepository:
    def __init__(self, db: AsyncConnection):
        self._db = db

    async def get_by_id(self, id: int) -> User | None:
        row = await self._db.fetchone("SELECT * FROM users WHERE id = $1", id)
        return User(**row) if row else None
```

### Service Layer

```python
class UserService:
    def __init__(
        self,
        repo: UserRepository,
        email: EmailService,
        hasher: PasswordHasher,
    ):
        self._repo = repo
        self._email = email
        self._hasher = hasher

    async def register(self, data: UserCreate) -> User:
        existing = await self._repo.get_by_email(data.email)
        if existing:
            raise ConflictError("Email already registered")

        hashed = self._hasher.hash(data.password)
        user = await self._repo.create({**data.dict(), "password_hash": hashed})
        await self._email.send_welcome(user)
        return user
```

### Strategy Pattern

```python
from typing import Protocol

class PricingStrategy(Protocol):
    def calculate(self, base_price: float) -> float: ...

class RegularPricing:
    def calculate(self, base_price: float) -> float:
        return base_price

class PremiumPricing:
    def calculate(self, base_price: float) -> float:
        return base_price * 0.8

class HolidayPricing:
    def __init__(self, discount: float):
        self.discount = discount

    def calculate(self, base_price: float) -> float:
        return base_price * (1 - self.discount)

def get_pricing_strategy(user_tier: str) -> PricingStrategy:
    strategies = {
        "regular": RegularPricing(),
        "premium": PremiumPricing(),
    }
    return strategies.get(user_tier, RegularPricing())
```

### Result Type (Error Handling Without Exceptions)

```python
from dataclasses import dataclass
from typing import TypeVar, Generic

T = TypeVar("T")
E = TypeVar("E")

@dataclass
class Ok(Generic[T]):
    value: T

@dataclass
class Err(Generic[E]):
    error: E

Result = Ok[T] | Err[E]

def divide(a: float, b: float) -> Result[float, str]:
    if b == 0:
        return Err("Division by zero")
    return Ok(a / b)

result = divide(10, 0)
match result:
    case Ok(value):
        print(f"Result: {value}")
    case Err(error):
        print(f"Error: {error}")
```

### Factory Pattern

```python
from typing import Callable

class PaymentProcessor:
    _handlers: dict[str, Callable] = {}

    @classmethod
    def register(cls, provider: str):
        def decorator(handler: Callable):
            cls._handlers[provider] = handler
            return handler
        return decorator

    @classmethod
    def process(cls, provider: str, amount: float) -> PaymentResult:
        handler = cls._handlers.get(provider)
        if not handler:
            raise ValueError(f"Unknown provider: {provider}")
        return handler(amount)

@PaymentProcessor.register("stripe")
def process_stripe(amount: float) -> PaymentResult:
    return stripe_charge(amount)

@PaymentProcessor.register("paypal")
def process_paypal(amount: float) -> PaymentResult:
    return paypal_charge(amount)
```

## Data Modeling

```python
from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime

class UserCreate(BaseModel):
    email: EmailStr
    name: str
    age: int

    @field_validator("name")
    @classmethod
    def name_must_not_be_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Name cannot be empty")
        return v.strip()

class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    created_at: datetime

    model_config = {"from_attributes": True}
```

## Rules

- Protocol over abstract class for interfaces.
- Pydantic for data validation at boundaries.
- Composition over inheritance.
- `match` statements for pattern matching (3.10+).
- Type hints everywhere. `mypy --strict`.
- Dependency injection via constructor.
- Immutable data with `@dataclass(frozen=True)`.
- `asyncio` for I/O-bound, sync for CPU-bound.
