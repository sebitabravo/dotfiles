---
name: tanstack-query
description: Critical TanStack Query v5 patterns — query keys, caching, mutations, SSR, optimistic updates. Use when writing data fetching, mutations, or cache logic in React.
---

# TanStack Query — Critical Patterns

Rules extracted from auditing 20+ patterns in a legacy codebase. Only what causes real bugs.

## Query Keys

### Always an array, hierarchical, with dependencies

```tsx
// BAD: flat string, no dependencies
useQuery({ queryKey: 'todos', queryFn: fetchTodos })

// BAD: missing variable in key — cache collision across users
useQuery({ queryKey: ['posts'], queryFn: () => fetchPostsByUser(userId) })

// GOOD: hierarchical array, every dependency included
useQuery({
  queryKey: ['todos', { status: 'done', page: 1 }],
  queryFn: () => fetchTodos({ status: 'done', page: 1 }),
})
```

**Rule**: if the `queryFn` uses a variable, that variable belongs in the `queryKey`. No exceptions.

### Query Key Factories (10+ queries)

```tsx
// lib/query-keys.ts
export const todoKeys = {
  all:    ['todos'] as const,
  lists:  () => [...todoKeys.all, 'list'] as const,
  list:   (filters: TodoFilters) => [...todoKeys.lists(), filters] as const,
  detail: (id: number) => [...todoKeys.all, 'detail', id] as const,
}

// Usage
useQuery({ queryKey: todoKeys.list({ status: 'active' }), queryFn: ... })

// Precise invalidation
queryClient.invalidateQueries({ queryKey: todoKeys.all })     // everything
queryClient.invalidateQueries({ queryKey: todoKeys.detail(5) }) // one
```

## Caching

### staleTime by volatility

| Data type | staleTime |
|---|---|
| Real-time (stocks, feeds) | `0` |
| Notifications | `30s - 1min` |
| UGC (posts, comments) | `1 - 5min` |
| Reference (categories, config) | `10 - 30min` |
| Static | `Infinity` |

```tsx
// Sensible default, override per query
const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 60 * 1000 } },
})
```

Stale data returns instantly. Refetch happens in the background. `staleTime: 0` (default) = refetch on every mount.

### gcTime — retention after unmount

```tsx
// Frequent routes: keep in cache
useQuery({ queryKey: ['dashboard'], queryFn: ..., gcTime: 30 * 60 * 1000 })

// Large data viewed once: release quickly
useQuery({ queryKey: ['report', id], queryFn: ..., gcTime: 2 * 60 * 1000 })
```

Default 5 min. For SSR: never `gcTime: 0` (2000ms minimum for hydration).

### Targeted invalidation, not broad

```tsx
// BAD: invalidates everything
queryClient.invalidateQueries()

// BAD: invalidates too much
queryClient.invalidateQueries({ queryKey: ['todos'] })

// GOOD: exact invalidation + related
queryClient.invalidateQueries({ queryKey: ['todos', todoId] })
queryClient.invalidateQueries({ queryKey: ['todos', 'list'] })
```

Use `exact: true` for a single query. Use a predicate for complex cases.

## Mutations

### Optimistic Update Pattern

```tsx
const mutation = useMutation({
  mutationFn: toggleTodo,
  onMutate: async (todoId) => {
    await queryClient.cancelQueries({ queryKey: ['todos'] })  // 1. cancelar refetch
    const previous = queryClient.getQueryData(['todos'])        // 2. snapshot
    queryClient.setQueryData(['todos'], (old) =>                // 3. optimista
      old.map(t => t.id === todoId ? { ...t, done: !t.done } : t))
    return { previous }                                         // 4. rollback context
  },
  onError: (err, vars, ctx) => {
    queryClient.setQueryData(['todos'], ctx?.previous)          // rollback
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['todos'] })      // sync final
  },
})
```

### Cancel queries before mutating

Always `cancelQueries` inside `onMutate` before an optimistic update. Stops an in-flight refetch from overwriting the optimistic change.

### Invalidate related queries after a mutation

```tsx
onSuccess: (data, { postId }) => {
  queryClient.invalidateQueries({ queryKey: ['posts', postId] })
  queryClient.invalidateQueries({ queryKey: ['posts', postId, 'comments'] })
  queryClient.invalidateQueries({ queryKey: ['posts', postId, 'comment-count'] })
}
```

Think about EVERY query that displays data the mutation touches.

## SSR — Dehydrate/Hydrate

```tsx
// Server Component (Next.js App Router)
import { dehydrate, HydrationBoundary, QueryClient } from '@tanstack/react-query'

export default async function PostsPage() {
  const queryClient = new QueryClient()                          // one per request
  await queryClient.prefetchQuery(postQueries.list())
  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <PostList />
    </HydrationBoundary>
  )
}

// Client Component
'use client'
export function PostList() {
  const { data } = useSuspenseQuery(postQueries.list())          // usa cache hidratada
  return <ul>{data.map(p => <li key={p.id}>{p.title}</li>)}</ul>
}
```

- A new `QueryClient` per request (avoids leaks between users).
- `staleTime > 0` on the server (prevents an immediate client refetch).
- Serialize carefully: `JSON.stringify` is XSS-prone. Use a safe serializer.

## Query Cancellation

```tsx
// Pasar signal a fetch/axios — automatico
useQuery({
  queryKey: ['search', term],
  queryFn: async ({ signal }) => {
    const res = await fetch(`/api/search?q=${term}`, { signal })
    return res.json()
  },
})
```

The old query key is cancelled automatically. Prevents race conditions in search-as-you-type.

## Errors with Suspense

```tsx
import { useQueryErrorResetBoundary } from '@tanstack/react-query'
import { ErrorBoundary } from 'react-error-boundary'

function QueryErrorBoundary({ children }) {
  const { reset } = useQueryErrorResetBoundary()
  return (
    <ErrorBoundary onReset={reset} fallbackRender={({ error, resetErrorBoundary }) => (
      <div><p>{error.message}</p><button onClick={resetErrorBoundary}>Retry</button></div>
    )}>
      {children}
    </ErrorBoundary>
  )
}
```

`useQueryErrorResetBoundary` clears the error state. Without it, the retry does not work.

## Prefetching (hover/focus)

```tsx
<Link
  to={`/posts/${post.id}`}
  onMouseEnter={() => queryClient.prefetchQuery(postQueries.detail(post.id))}
  onFocus={() => queryClient.prefetchQuery(postQueries.detail(post.id))}
>
```

Set `staleTime` on the prefetch so it does not refetch immediately. 100ms delay for fast hover.

## Cheatsheet

| Problem | Likely cause | Fix |
|---|---|---|
| Stale data across users | Missing variable in queryKey | `queryKey: ['x', userId]` |
| Refetch on every navigation | `staleTime: 0` (default) | `staleTime: 5 * 60 * 1000` |
| Slow UI after a mutation | Waiting for the refetch | Optimistic update |
| Mutation does not refresh the UI | Missing invalidateQueries | Invalidate every affected query |
| Memory leak in an SPA | `gcTime: Infinity` | `gcTime` based on visit frequency |
| SSR loading flash | Client refetches after hydrate | `staleTime > 0` on the server |
| Search input laggy | Old requests not cancelled | Pass `signal` to fetch |
