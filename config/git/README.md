# Git Config y Seguridad

## `.gitconfig.local` — Configuracion personal

El `.gitconfig` del repo esta pensado para ser compartido (aliases, delta, colores, etc.). Los datos personales (nombre, email) van en un archivo separado que NO se versiona.

### Setup

```bash
# 1. Copia el template a tu home
cp .gitconfig.local.template ~/.gitconfig.local

# 2. Editalo con tu nombre y email
```

---

## Gitleaks — Pre-commit hook anti-secretos

Evita que commitees accidentalmente tokens, API keys, o passwords en texto plano.

### Como funciona

Cada vez que haces `git commit`, el hook escanea los archivos staged con [gitleaks](https://github.com/gitleaks/gitleaks). Si detecta algo que parece un secreto (AWS keys, GitHub tokens, OpenAI keys, etc.), te avisa.

Por defecto esta en **modo WARN** — te muestra el leak pero no bloquea el commit. Podes activar **modo BLOCK** si queres que el commit falle:

```bash
export GITLEAKS_BLOCK=true
```

### Instalacion

**Opcion A — Por repo (recomendado):**

```bash
cp config/git/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Repeti en cada repo donde quieras proteccion.

**Opcion B — Global (todos los repos):**

```bash
git config --global core.hooksPath /ruta/a/tu/dotfiles/config/git/hooks
```

**Advertencia:** Esto aplica el hook a TODOS los repos que clones, incluyendo proyectos ajenos donde contribuis. Si no queres interferencia, usa Opcion A.

### Configuracion

El archivo `.gitleaks.toml` en la raiz del repo contiene reglas de allowlist para falsos positivos comunes (placeholders, templates, READMEs, etc.). Copialo a cada repo donde uses el hook:

```bash
cp .gitleaks.toml /ruta/a/tu/proyecto/
```

### Desactivar por repo

```bash
git config hooks.gitleaks.disabled true
```

### Falsos positivos

Si gitleaks marca algo que NO es un secreto real, agregalo al allowlist en `.gitleaks.toml`:

```toml
[allowlist]
  paths = ["ruta/al/archivo"]
  regexes = ["(?i)mi-falso-positivo"]
```

Tambien podes usar comentarios inline en el codigo:

```python
API_KEY = "placeholder-123"  # gitleaks:allow
```
