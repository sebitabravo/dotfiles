---
name: tanstack-query
description: Patrones criticos de TanStack Query v5 — query keys, caching, mutations, SSR, optimistic updates. Usar cuando se escriba data fetching, mutations, o cache en React.
---

# TanStack Query — Patrones Criticos

Reglas extraidas de audit de 20+ patrones en codebase legacy. Solo lo que causa bugs reales.

## Query Keys

### Array siempre, jerarquico, con dependencias

```tsx
// MAL: string plana, sin dependencias
useQuery({ queryKey: 'todos', queryFn: fetchTodos })

// MAL: falta variable en key — colision de cache entre usuarios
useQuery({ queryKey: ['posts'], queryFn: () => fetchPostsByUser(userId) })

// BIEN: array jerarquico, todas las dependencias incluidas
useQuery({
  queryKey: ['todos', { status: 'done', page: 1 }],
  queryFn: () => fetchTodos({ status: 'done', page: 1 }),
})
```

**Regla**: si el `queryFn` usa una variable, esa variable va en el `queryKey`. Sin excepcion.

### Query Key Factories (10+ queries)

```tsx
// lib/query-keys.ts
export const todoKeys = {
  all:    ['todos'] as const,
  lists:  () => [...todoKeys.all, 'list'] as const,
  list:   (filters: TodoFilters) => [...todoKeys.lists(), filters] as const,
  detail: (id: number) => [...todoKeys.all, 'detail', id] as const,
}

// Uso
useQuery({ queryKey: todoKeys.list({ status: 'active' }), queryFn: ... })

// Invalidacion precisa
queryClient.invalidateQueries({ queryKey: todoKeys.all })     // todo
queryClient.invalidateQueries({ queryKey: todoKeys.detail(5) }) // uno
```

## Caching

### staleTime segun volatilidad

| Tipo de dato | staleTime |
|---|---|
| Real-time (stocks, feeds) | `0` |
| Notificaciones | `30s - 1min` |
| UGC (posts, comments) | `1 - 5min` |
| Referencia (categorias, config) | `10 - 30min` |
| Estatico | `Infinity` |

```tsx
// Default sensato, override por query
const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 60 * 1000 } },
})
```

Dato stale se devuelve instantaneo. Refetch en background. `staleTime: 0` (default) = refetch en cada mount.

### gcTime — retencion post-unmount

```tsx
// Rutas frecuentes: mantener en cache
useQuery({ queryKey: ['dashboard'], queryFn: ..., gcTime: 30 * 60 * 1000 })

// Datos grandes vistos una vez: liberar rapido
useQuery({ queryKey: ['report', id], queryFn: ..., gcTime: 2 * 60 * 1000 })
```

Default 5 min. Para SSR: nunca `gcTime: 0` (minimo 2000ms para hidratacion).

### Invalidacion dirigida, no broad

```tsx
// MAL: invalida todo
queryClient.invalidateQueries()

// MAL: invalida de mas
queryClient.invalidateQueries({ queryKey: ['todos'] })

// BIEN: invalidacion exacta + relacionadas
queryClient.invalidateQueries({ queryKey: ['todos', todoId] })
queryClient.invalidateQueries({ queryKey: ['todos', 'list'] })
```

Usar `exact: true` para una sola query. Usar predicate para casos complejos.

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

### Cancelar queries antes de mutar

Siempre `cancelQueries` en `onMutate` antes de un update optimista. Previene que un refetch pendiente sobrescriba el cambio optimista.

### Invalidar relacionadas post-mutation

```tsx
onSuccess: (data, { postId }) => {
  queryClient.invalidateQueries({ queryKey: ['posts', postId] })
  queryClient.invalidateQueries({ queryKey: ['posts', postId, 'comments'] })
  queryClient.invalidateQueries({ queryKey: ['posts', postId, 'comment-count'] })
}
```

Pensar en TODAS las queries que muestran datos afectados por la mutacion.

## SSR — Dehydrate/Hydrate

```tsx
// Server Component (Next.js App Router)
import { dehydrate, HydrationBoundary, QueryClient } from '@tanstack/react-query'

export default async function PostsPage() {
  const queryClient = new QueryClient()                          // uno por request
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

- Nuevo `QueryClient` por request (evita leaks entre usuarios).
- `staleTime > 0` en server (previene refetch inmediato en cliente).
- Serializar con cuidado: `JSON.stringify` es vulnerable a XSS. Usar serializer seguro.

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

Query key vieja se cancela automaticamente. Previene race conditions en search-as-you-type.

## Errores con Suspense

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

`useQueryErrorResetBoundary` limpia el estado de error. Sin esto, el retry no funciona.

## Prefetching (hover/focus)

```tsx
<Link
  to={`/posts/${post.id}`}
  onMouseEnter={() => queryClient.prefetchQuery(postQueries.detail(post.id))}
  onFocus={() => queryClient.prefetchQuery(postQueries.detail(post.id))}
>
```

Poner `staleTime` en el prefetch para que no refetche inmediato. Delay de 100ms para hover rapido.

## Cheatsheet

| Problema | Causa probable | Fix |
|---|---|---|
| Datos stale entre usuarios | Falta variable en queryKey | `queryKey: ['x', userId]` |
| Refetch en cada navegacion | `staleTime: 0` (default) | `staleTime: 5 * 60 * 1000` |
| UI lenta post-mutacion | Esperando refetch | Optimistic update |
| Mutacion no refresca UI | Falta invalidateQueries | Invalidar todas las queries afectadas |
| Memory leak en SPA | `gcTime: Infinity` | `gcTime` segun frecuencia de visita |
| SSR flash de loading | Cliente refetcha tras hydrate | `staleTime > 0` en server |
| Search input laggy | Requests viejas no canceladas | Pasar `signal` a fetch |
