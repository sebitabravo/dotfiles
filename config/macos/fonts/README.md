# Fonts

Nerd Fonts para la terminal y el editor de codigo.
`./install.sh` las instala automaticamente en macOS; no se usan casks de Homebrew.

## Fuentes incluidas

| Font | Original | Descargar |
|---|---|---|---|
| **Cascadia Code PL** | Microsoft | <https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip> |
| **FiraCode Nerd Font** | Nerd Fonts | <https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip> |
| **JetBrains Mono** | JetBrains | <https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip> |
| **Meslo LG** | Andre Berg | <https://codeload.github.com/andreberg/Meslo-Font/zip/09a431d546d211130352c28eb0466e5d7d5aeaf0> |
| **IosevkaTerm NF** | Nerd Fonts | <https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/IosevkaTerm.zip> |

## Instalacion

El instalador descarga solo los archivos HTTPS versionados de la tabla, valida
cada SHA-256, los extrae en un directorio temporal y copia los `.ttf` nuevos a
`~/Library/Fonts`. Font Book los detecta desde ese destino sin automatizar la
interfaz grafica.

```bash
./install.sh
```

Para inspeccionar el plan sin descargar, extraer ni escribir fuentes:

```bash
./install.sh --dry-run
```

La instalacion es idempotente: una fuente ya presente con los mismos bytes se
omite. Si existe un archivo con el mismo nombre pero distinto contenido, el
instalador aborta en vez de reemplazar una fuente del usuario. Tambien aborta
ante fallas de descarga, checksum, extraccion o si un archivo no contiene
ningun `.ttf`; el staging temporal se elimina al salir.
