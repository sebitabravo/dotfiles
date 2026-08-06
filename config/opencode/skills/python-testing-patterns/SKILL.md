---
name: python-testing-patterns
description:
  Python testing patterns with pytest, fixtures, mocking, parametrize, TDD
  workflow, and test organization best practices.
---

This skill assumes the test dependency is declared by the project. Run it via
`uv run pytest`; never assume a global test executable exists on the host.

## Test Structure

```
tests/
├── conftest.py           # Shared fixtures
├── unit/
│   ├── test_services/
│   │   ├── test_user_service.py
│   │   └── test_payment_service.py
│   └── test_models/
│       └── test_user.py
├── integration/
│   ├── test_api/
│   │   ├── test_users_api.py
│   │   └── test_auth_api.py
│   └── test_repositories/
│       └── test_user_repo.py
└── e2e/
    └── test_checkout.py
```

## Fixtures

### conftest.py

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.database import get_db, engine
from app.models import Base

@pytest.fixture(autouse=True)
async def setup_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

@pytest.fixture
async def authenticated_client(client: AsyncClient, db_session):
    user = await create_test_user(db_session)
    token = create_test_token(user.id)
    client.headers["Authorization"] = f"Bearer {token}"
    client._test_user = user
    yield client

@pytest.fixture
def mock_email_service(mocker):
    return mocker.patch("app.services.email.EmailService.send", return_value=None)
```

## Parametrize

```python
@pytest.mark.parametrize("email,expected_valid", [
    ("user@example.com", True),
    ("invalid-email", False),
    ("", False),
    ("a@b.c", True),
    ("user+tag@example.com", True),
])
async def test_email_validation(email: str, expected_valid: bool):
    result = validate_email(email)
    assert result.is_valid == expected_valid

@pytest.mark.parametrize("amount,discount,expected", [
    (100, 0, 100),
    (100, 0.1, 90),
    (100, 0.5, 50),
    (0, 0.1, 0),
])
def test_price_calculation(amount: float, discount: float, expected: float):
    assert calculate_price(amount, discount) == expected
```

## Mocking

### Service Mock

```python
async def test_send_welcome_email(mocker, user_service):
    mock_send = mocker.patch("app.services.email.EmailService.send")

    user = await user_service.register(UserCreate(
        email="test@example.com",
        name="Test",
        password="password123",
    ))

    mock_send.assert_called_once()
    call_args = mock_send.call_args
    assert call_args[1]["recipient"] == user.email
    assert "welcome" in call_args[1]["subject"].lower()
```

### Database Mock

```python
async def test_get_user_not_found(mock_db):
    mock_db.fetchone.return_value = None
    repo = UserRepository(mock_db)

    result = await repo.get_by_id(999)

    assert result is None
    mock_db.fetchone.assert_called_once()
```

### Time Mock

```python
from freezegun import freeze_time

@freeze_time("2025-01-15 10:00:00")
def test_subscription_expiration():
    sub = Subscription(created_at=datetime.utcnow())
    assert sub.is_expired is False

    with freeze_time("2025-02-15 10:00:00"):
        assert sub.is_expired is True
```

## TDD Pattern

```python
# RED: Write failing test first
async def test_create_user_with_duplicate_email_raises_conflict(client, db_session):
    await create_test_user(db_session, email="test@example.com")

    response = await client.post("/api/users", json={
        "email": "test@example.com",
        "name": "Duplicate",
        "password": "password123",
    })

    assert response.status_code == 409

# GREEN: Minimum code to pass
# REFACTOR: Clean up while tests pass
```

## Async Testing

```python
@pytest.mark.asyncio
async def test_concurrent_requests(client):
    import asyncio
    tasks = [client.get("/api/health") for _ in range(10)]
    responses = await asyncio.gather(*tasks)
    assert all(r.status_code == 200 for r in responses)
```

## Custom Markers

```python
# pytest.ini or pyproject.toml
[tool.pytest.ini_options]
markers = [
    "slow: marks tests as slow",
    "integration: marks integration tests",
    "e2e: marks end-to-end tests",
]

# Usage
@pytest.mark.slow
@pytest.mark.integration
async def test_full_import():
    await import_large_dataset()
```

## Coverage

```bash
pytest --cov=app --cov-report=term-missing --cov-fail-under=80
```

## Rules

- One assertion per test concept. Group related assertions in same test.
- `conftest.py` for shared fixtures. No fixtures in test files that are shared.
- `mocker.patch` for external dependencies only. Never mock what you own.
- `@pytest.mark.parametrize` for data-driven tests.
- TDD: RED (failing test) → GREEN (minimal pass) → REFACTOR.
- Test names describe behavior: `test_<scenario>_<expected_outcome>`.
- Arrange-Act-Assert pattern.
- `autouse=True` only for cross-cutting concerns (DB setup, cleanup).
- Integration tests with real DB, not mocks.
