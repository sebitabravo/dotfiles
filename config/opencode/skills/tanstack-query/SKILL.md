---
name: tanstack-query
description: TanStack Query v5 patterns for data fetching, mutations, caching, optimistic updates, and cache invalidation in React applications.
---

## Core Patterns

### Query Setup

```tsx
import { QueryClient } from '@tanstack/react-query'

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,
      gcTime: 10 * 60 * 1000,
      retry: 2,
      refetchOnWindowFocus: false,
    },
  },
})
```

### Query Keys Strategy

```tsx
// Factory pattern for type-safe keys
export const todoKeys = {
  all: ['todos'] as const,
  lists: () => [...todoKeys.all, 'list'] as const,
  list: (filters: TodoFilters) => [...todoKeys.lists(), filters] as const,
  details: () => [...todoKeys.all, 'detail'] as const,
  detail: (id: string) => [...todoKeys.details(), id] as const,
}
```

### useQuery

```tsx
function useTodo(id: string) {
  return useQuery({
    queryKey: todoKeys.detail(id),
    queryFn: () => fetchTodo(id),
    enabled: !!id,
    select: (data) => transformTodo(data),
  })
}
```

### useMutation + Optimistic Update

```tsx
function useUpdateTodo() {
  return useMutation({
    mutationFn: (todo: UpdateTodo) => api.updateTodo(todo),
    onMutate: async (newTodo) => {
      await queryClient.cancelQueries({ queryKey: todoKeys.detail(newTodo.id) })
      const previous = queryClient.getQueryData(todoKeys.detail(newTodo.id))
      queryClient.setQueryData(todoKeys.detail(newTodo.id), newTodo)
      return { previous }
    },
    onError: (_err, _vars, context) => {
      queryClient.setQueryData(todoKeys.detail(_vars.id), context?.previous)
    },
    onSettled: (_data, _err, vars) => {
      queryClient.invalidateQueries({ queryKey: todoKeys.detail(vars.id) })
    },
  })
}
```

### Infinite Scroll

```tsx
function useInfiniteTodos(filters: TodoFilters) {
  return useInfiniteQuery({
    queryKey: [...todoKeys.list(filters), 'infinite'],
    queryFn: ({ pageParam }) => fetchTodos({ ...filters, cursor: pageParam }),
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    initialPageParam: undefined as string | undefined,
  })
}
```

### Parallel Queries

```tsx
function useDashboard(userId: string) {
  return useQueries({
    queries: [
      { queryKey: ['user', userId], queryFn: () => fetchUser(userId) },
      { queryKey: ['user-posts', userId], queryFn: () => fetchPosts(userId) },
      { queryKey: ['user-stats', userId], queryFn: () => fetchStats(userId) },
    ],
    combine: (results) => ({
      data: {
        user: results[0].data,
        posts: results[1].data,
        stats: results[2].data,
      },
      pending: results.some((r) => r.isPending),
      error: results.find((r) => r.isError)?.error,
    }),
  })
}
```

### Prefetching

```tsx
// Route-based prefetch
function TodoList() {
  const queryClient = useQueryClient()
  return todos.map((todo) => (
    <Link
      key={todo.id}
      to={`/todos/${todo.id}`}
      onMouseEnter={() =>
        queryClient.prefetchQuery({
          queryKey: todoKeys.detail(todo.id),
          queryFn: () => fetchTodo(todo.id),
        })
      }
    >
      {todo.title}
    </Link>
  ))
}
```

### Server-Side with Next.js

```tsx
// app/todos/page.tsx
export default async function TodosPage() {
  void queryClient.prefetchQuery({
    queryKey: todoKeys.lists(),
    queryFn: fetchTodos,
  })
  return <TodoList />
}

// Hydration boundary
import { HydrationBoundary, dehydrate } from '@tanstack/react-query'

export default async function Layout({ children }) {
  void queryClient.prefetchQuery({ queryKey: ['todos'], queryFn: fetchTodos })
  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      {children}
    </HydrationBoundary>
  )
}
```

## Rules

- Factory pattern for query keys. Always.
- `enabled: false` for conditional queries, never conditional hooks.
- Optimistic updates for instant feedback on mutations.
- Invalidate related queries in `onSettled`, not `onSuccess`.
- `select` for data transformation at query level.
- `staleTime` > 0 for data that doesn't change every request.
- Never call hooks conditionally. Use `enabled` instead.
