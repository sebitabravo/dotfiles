#!/usr/bin/env bash
# process-utils.sh — utilidades compartidas para manejo de procesos.
#
# _process_tree_pids: retorna el PID y todos sus descendientes (no solo hijos
# directos). `pkill -P` solo alcanza una generacion; un runner real puede
# forkar workers que a su vez forkean, y esos nietos sobrevivirian al timeout.
# Discovery separado de signaling: un descendiente que muere con TERM puede
# dejar huerfanos antes de un segundo walk, por eso se captura una sola vez
# y se señaliza dos veces (TERM y KILL) sobre la misma lista.

_process_tree_pids() {
  local frontier="$1" all_pids="$1" pid children next

  while [ -n "$frontier" ]; do
    next=""
    for pid in $frontier; do
      children=$(pgrep -P "$pid" 2>/dev/null || true)
      [ -n "$children" ] && {
        next="$next $children"
        all_pids="$all_pids $children"
      }
    done
    frontier=$next
  done

  printf '%s' "$all_pids"
}
