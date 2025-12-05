# 🚀 Guía Rápida de Uso

## Instalación Inicial

```bash
# Clonar repositorio
git clone https://github.com/sebitabravo/dotfiles.git ~/dotfiles

# Instalar todo automáticamente
cd ~/dotfiles
./install.sh

# Reiniciar terminal
exec zsh
```

## Mantenimiento

### Actualizar configuraciones en el repo

```bash
# Desde cualquier lugar
cd ~/dotfiles
./backup.sh
```

Este script:
- ✅ Copia todas las configuraciones actuales
- ✅ Actualiza el Brewfile con paquetes instalados
- ✅ Pregunta si quieres hacer commit y push

### Actualizar sistema

```bash
# Actualizar Homebrew y paquetes
brew update && brew upgrade && brew cleanup

# Actualizar Oh My Zsh
omz update

# Actualizar Node.js
fnm install --lts
fnm use lts-latest

# Actualizar Python
pyenv install 3.14.1
pyenv global 3.14.1
```

## Comandos Útiles

### Git (con aliases configurados)

```bash
git graph              # Ver log gráfico
git ls                 # Listar archivos con iconos
git ll                 # Listar archivos detallado
git la                 # Listar todos los archivos
```

### Shell (aliases recomendados para agregar)

```bash
myip                   # Ver IP pública
tailscale             # Comando de Tailscale
```

### Node.js (fnm)

```bash
fnm list              # Ver versiones instaladas
fnm use 20            # Usar Node 20
fnm default 20        # Setear Node 20 como default
fnm install 18        # Instalar Node 18
```

### Python (pyenv)

```bash
pyenv versions        # Ver versiones instaladas
pyenv install 3.11.1  # Instalar versión específica
pyenv global 3.14.1   # Setear versión global
pyenv local 3.11.1    # Setear versión para proyecto actual
```

## Estructura del Repositorio

```
dotfiles/
├── .zshrc                  # Configuración principal de Zsh
├── .zprofile              # Variables de entorno
├── .gitconfig             # Configuración de Git
├── .p10k.zsh              # Tema Powerlevel10k
├── Brewfile               # Paquetes de Homebrew
├── install.sh             # Script de instalación
├── backup.sh              # Script de backup
├── README.md              # Este archivo
├── config/
│   ├── fastfetch/         # Info del sistema
│   ├── vscode/            # Settings de VS Code
│   └── claude/            # Configuración de Claude
└── docs/
    ├── MANUAL_INSTALL.md  # Apps de instalación manual
    ├── REVIEW_TECNICO.md  # Análisis técnico
    ├── raycast-extensions.md
    ├── stream-deck.md
    └── dock.sh            # Script de configuración del Dock
```

## Tips y Trucos

### Zsh

```bash
# Recargar configuración sin reiniciar terminal
source ~/.zshrc

# Ver todos los aliases disponibles
alias

# Buscar en historial
Ctrl + R
```

### Git

```bash
# Ver cambios antes de commit
git diff

# Ver cambios en archivos staged
git diff --cached

# Deshacer último commit (mantener cambios)
git reset HEAD~1 --soft

# Ver quién modificó cada línea
git blame <archivo>
```

### Homebrew

```bash
# Buscar paquete
brew search <nombre>

# Ver info de paquete
brew info <nombre>

# Ver paquetes instalados
brew list

# Ver servicios corriendo
brew services list

# Limpiar caché
brew cleanup
```

### VS Code

```bash
# Abrir VS Code desde terminal
code .

# Abrir archivo específico
code archivo.js

# Instalar extensión desde terminal
code --install-extension <extension-id>

# Ver extensiones instaladas
code --list-extensions
```

## Mejores Prácticas

### 1. Backup Regular
```bash
# Cada viernes o antes de cambios grandes
cd ~/dotfiles && ./backup.sh
```

### 2. Commits Descriptivos
```bash
git commit -m "feat: agregar alias para Docker"
git commit -m "fix: corregir PATH de Python"
git commit -m "docs: actualizar README con nuevos comandos"
```

### 3. Probar Antes de Commit
```bash
# Después de cambios en .zshrc
source ~/.zshrc

# Verificar que todo funciona
# Luego hacer backup
```

### 4. Mantener Limpio el Sistema
```bash
# Cada mes
brew update && brew upgrade && brew cleanup
brew doctor

# Limpiar caché de npm
npm cache clean --force

# Limpiar caché de pip
pip cache purge
```

## Troubleshooting

### Terminal lento

```bash
# Verificar qué está tardando
time zsh -i -c exit

# Deshabilitar temporalmente plugins
# En .zshrc, comentar plugins que no uses
```

### Conflictos de PATH

```bash
# Ver PATH actual
echo $PATH | tr ':' '\n'

# Verificar orden de precedencia
# El primero en el PATH tiene prioridad
```

### Homebrew no encuentra comandos

```bash
# Recargar environment
eval "$(/opt/homebrew/bin/brew shellenv)"

# O reiniciar terminal
exec zsh
```

### Git push requiere password

```bash
# Usar SSH en lugar de HTTPS
git remote set-url origin git@github.com:sebitabravo/dotfiles.git

# Configurar SSH keys
ssh-keygen -t ed25519 -C "tu-email@ejemplo.com"
# Agregar la key pública a GitHub
```

## Recursos Útiles

- [Oh My Zsh Docs](https://github.com/ohmyzsh/ohmyzsh/wiki)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [Homebrew Docs](https://docs.brew.sh/)
- [fnm GitHub](https://github.com/Schniz/fnm)
- [pyenv GitHub](https://github.com/pyenv/pyenv)
- [Git Aliases](https://git-scm.com/book/en/v2/Git-Basics-Git-Aliases)

## Extensiones VS Code Recomendadas

Ver tu archivo de settings, pero algunas esenciales:

- GitHub Copilot
- Error Lens
- Prettier
- ESLint
- GitLens
- Todo Tree
- Import Cost
- Path Intellisense
- Tailwind CSS IntelliSense

## Siguientes Pasos

1. ✅ Instalar dotfiles con `./install.sh`
2. ⬜ Configurar apps de `docs/MANUAL_INSTALL.md`
3. ⬜ Personalizar Powerlevel10k con `p10k configure`
4. ⬜ Instalar extensiones de Raycast (ver `docs/raycast-extensions.md`)
5. ⬜ Configurar Stream Deck (ver `docs/stream-deck.md`)
6. ⬜ Hacer backup inicial con `./backup.sh`

---

**Nota**: Este es un documento vivo. Actualízalo con tus propios comandos y trucos que descubras.
