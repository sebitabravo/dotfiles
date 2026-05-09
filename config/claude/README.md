# Claude Code Config

Configuracion personal de Claude Code con agentes especializados, tema tweakcc, y statusline custom.

## Instalacion

```bash
# Symlink de config
ln -sf ~/Developer/dotfiles/config/claude/settings.json ~/.claude/settings.json
ln -sf ~/Developer/dotfiles/config/claude/statusline.sh ~/.claude/statusline.sh
ln -sf ~/Developer/dotfiles/config/claude/tweakcc-theme.json ~/.claude/tweakcc-theme.json

# Agentes
mkdir -p ~/.claude/agents
for f in ~/Developer/dotfiles/config/claude/agents/*.md; do
  ln -sf "$f" ~/.claude/agents/
done
```

## Caveman Mode (recomendado)

[Caveman](https://github.com/JuliusBrussee/caveman) comprime la comunicacion de Claude ~75% sin perder precision tecnica. Ahorra tokens, reduce costos, y acelera respuestas.

**Instalar:**

```bash
claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman
```

**Usar en modo `full`** (balance optimo entre compresion y claridad):

```
/caveman full
```

Tambien disponible: `lite` (sutil) y `ultra` (maxima compresion). El badge `[CAVEMAN]` en la statusline confirma que esta activo.
