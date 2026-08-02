---
name: django-patterns
description: >
  Django and DRF patterns including ORM optimization, viewsets, serializers, caching, signals, middleware, and testing.
  Use when writing or reviewing Django/DRF code: models, viewsets, serializers, querysets and N+1, signals, middleware, or Django tests.
---

## Project Structure

```
project/
├── config/              # Project settings
│   ├── settings/
│   │   ├── base.py
│   │   ├── development.py
│   │   └── production.py
│   ├── urls.py
│   └── wsgi.py
├── apps/
│   ├── users/
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── services.py
│   │   └── tests/
│   └── orders/
├── core/                # Shared utilities
│   ├── middleware.py
│   ├── pagination.py
│   └── permissions.py
└── templates/
```

## ORM Patterns

### Model Definition

```python
from django.db import models

class TimestampMixin(models.Model):
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True

class User(TimestampMixin):
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=100)
    role = models.CharField(max_length=20, choices=[("user", "User"), ("admin", "Admin")], default="user")

    class Meta:
        db_table = "users"
        indexes = [
            models.Index(fields=["email"]),
            models.Index(fields=["role", "created_at"]),
        ]

    def __str__(self) -> str:
        return self.email
```

### Query Optimization

```python
# BAD: N+1 queries
orders = Order.objects.all()
for order in orders:
    print(order.user.name)  # Extra query per iteration

# GOOD: select_related (ForeignKey)
orders = Order.objects.select_related("user").all()

# GOOD: prefetch_related (ManyToMany / reverse FK)
users = User.objects.prefetch_related("orders", "orders__items").all()

# GOOD: Only needed fields
users = User.objects.only("id", "email", "name")

# GOOD: Aggregation
from django.db.models import Count, Sum
users = User.objects.annotate(
    order_count=Count("orders"),
    total_spent=Sum("orders__total"),
)
```

## DRF Patterns

### Serializers

```python
from rest_framework import serializers

class UserSerializer(serializers.ModelSerializer):
    order_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = User
        fields = ["id", "email", "name", "role", "order_count", "created_at"]
        read_only_fields = ["id", "created_at"]
        extra_kwargs = {
            "email": {"validators": []},  # Override if needed
        }

    def validate_email(self, value: str) -> str:
        if User.objects.filter(email=value).exclude(pk=self.instance.pk if self.instance else None).exists():
            raise serializers.ValidationError("Email already in use")
        return value
```

### ViewSets

```python
from rest_framework import viewsets, status, filters
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

class UserViewSet(viewsets.ModelViewSet):
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ["name", "email"]
    ordering_fields = ["created_at", "name"]
    ordering = ["-created_at"]

    def get_queryset(self):
        return User.objects.annotate(
            order_count=Count("orders")
        ).only("id", "email", "name", "role", "created_at")

    def perform_create(self, serializer):
        user = serializer.save()
        send_welcome_email.delay(user.id)

    @action(detail=True, methods=["post"])
    def deactivate(self, request, pk=None):
        user = self.get_object()
        user.is_active = False
        user.save(update_fields=["is_active", "updated_at"])
        return Response({"status": "deactivated"})
```

### Pagination

```python
# core/pagination.py
from rest_framework.pagination import CursorPagination

class StandardPagination(CursorPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
    ordering = "-created_at"
```

### Permissions

```python
from rest_framework.permissions import BasePermission

class IsOwnerOrAdmin(BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.user.role == "admin":
            return True
        return obj.user_id == request.user.id
```

## Caching

```python
from django.core.cache import cache

def get_user_stats(user_id: int) -> dict:
    cache_key = f"user_stats:{user_id}"
    stats = cache.get(cache_key)
    if stats is None:
        stats = calculate_user_stats(user_id)
        cache.set(cache_key, stats, timeout=300)  # 5 min
    return stats

# Cache invalidation
def invalidate_user_stats(user_id: int) -> None:
    cache.delete(f"user_stats:{user_id}")
```

## Signals

```python
from django.db.models.signals import post_save
from django.dispatch import receiver

@receiver(post_save, sender=User)
def on_user_created(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
        send_welcome_email.delay(instance.id)
```

## Testing

```python
import pytest
from rest_framework.test import APIClient

@pytest.fixture
def api_client():
    return APIClient()

@pytest.fixture
def authenticated_client(api_client, user):
    api_client.force_authenticate(user=user)
    return api_client

@pytest.mark.django_db
class TestUserAPI:
    def test_list_users(self, authenticated_client):
        response = authenticated_client.get("/api/users/")
        assert response.status_code == 200

    def test_create_user(self, authenticated_client):
        response = authenticated_client.post("/api/users/", {
            "email": "new@example.com",
            "name": "New User",
        })
        assert response.status_code == 201
```

## Rules

- `select_related` / `prefetch_related` for every list endpoint.
- Services layer for business logic. Views call services.
- Custom permissions over inline checks.
- Cursor pagination for large datasets.
- Cache with explicit invalidation strategy.
- `pytest-django` with `@pytest.mark.django_db`.
- `only()` / `defer()` to limit query fields.
- Signals for cross-app communication only.
