# Claude agent tooling en macOS

## Runtime único

- **Python**: usar el intérprete activo de `pyenv` (`pyenv exec python`). No
  instalar `python@3.x` desde Homebrew para estas herramientas: la formula de
  `semgrep` y varias herramientas de análisis arrastran un Python separado.
- **Node.js**: usar el Node default de Herd. Las dependencias JavaScript son
  locales a cada skill y no instalan otro runtime Node.
- **Rust**: usar `rustup` en `~/.cargo`; no usar la formula Homebrew `rust`, cuya
  grafía de dependencias agrega `python@3.14` en este host.

## Python

Desde la raíz del repositorio:

```bash
pyenv exec python -m pip install -r config/claude/agent-tools/requirements.txt
pyenv rehash
```

Esto instala las herramientas dentro de la versión Python ya administrada por
`pyenv` y deja sus ejecutables visibles mediante los shims. No crea otro
intérprete.

## Skills Node

Las skills que tienen `package.json` usan el Node de Herd y sus propias carpetas
`node_modules` en el runtime desplegado. Después de ejecutar `./install.sh`:

```bash
npm ci --ignore-scripts --prefix "$HOME/.claude/skills/pptx"
npm ci --ignore-scripts --prefix "$HOME/.claude/skills/stitch-react-components"
```

Los lockfiles deben permanecer versionados. `@swc/core` se valida después de la
instalación; si su binario nativo no queda disponible con scripts bloqueados,
se habilita únicamente su lifecycle script de forma explícita.

### CLI globales

Los CLI globales que necesitan Node también se instalan dentro del prefix de
Herd, nunca con otro Node:

```bash
npm install --global --ignore-scripts neonctl@3.2.2
```

Verificación:

```bash
command -v neonctl
neonctl --version
```

## Rust

Rust se instala con el instalador oficial `rustup` y queda en `~/.cargo/bin`.
El `.zshenv` versionado agrega ese directorio al `PATH`; no se instala Rust por
Homebrew.

## Fuera del host

No se agregan automáticamente herramientas de explotación, ataques de
credenciales o post-explotación. Esas capacidades siguen delegadas al plano VM
según `config/claude/agents/vulnerability-hunter.md`.
