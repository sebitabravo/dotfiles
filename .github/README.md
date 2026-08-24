## Verificación

```bash
bash .github/validate.sh
bash .github/test/check-runtime-parity.sh --strict
bash .github/test/check-provider-runtime-parity.sh --strict
bash .github/test/doctor.sh
ghostty +validate-config --config-file="$HOME/.config/ghostty/config.ghostty"
fastfetch --config="$HOME/.config/fastfetch/config.jsonc"
brew bundle check --no-upgrade --file=Brewfile
```

`validate.sh` bloquea si falta una suite declarada o si no puede ejecutar
ShellCheck; nunca reporta cobertura parcial como válida. La validez de los JSON
y hooks tampoco prueba credenciales, cuota ni inferencia de un provider externo.
