# Fonts

Nerd Fonts para la terminal y el editor de codigo.
Se instalan MANUALMENTE (no via brew) porque no son herramientas de desarrollo.
Descargar, descomprimir, seleccionar todos los `.ttf` y abrir con FontBook.

## Fuentes incluidas

| Font | Original | Descargar |
|---|---|---|---|
| **Cascadia Code** | Microsoft | https://github.com/microsoft/cascadia-code/releases/latest |
| **FiraCode Nerd Font** | Nerd Fonts | https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip |
| **JetBrains Mono** | JetBrains | https://github.com/JetBrains/JetBrainsMono/releases |
| **Meslo LG** | Andre Berg | https://github.com/andreberg/Meslo-Font |

## Instalacion

```bash
# Opcion 1: Descargar e instalar manualmente
# 1. Ir al link de descarga
# 2. Descomprimir el ZIP
# 3. Seleccionar todos los .ttf
# 4. Clic derecho -> Abrir con FontBook
# 5. FontBook -> Instalar fuente

# Opcion 2: Script rapido (curl + unzip + FontBook)

# Cascadia Code — Microsoft
curl -LO "https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip"
unzip -q "CascadiaCode-2407.24.zip" -d "CascadiaCode/"
open "CascadiaCode"/*.ttf
echo "Instala Cascadia Code en FontBook"

# JetBrains Mono — JetBrains
curl -LO "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
unzip -q "JetBrainsMono-2.304.zip" -d "JetBrainsMono/"
open "JetBrainsMono"/*.ttf
echo "Instala JetBrains Mono en FontBook"

# FiraCode — Nerd Fonts
curl -LO "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
unzip -q "FiraCode.zip" -d "FiraCode/"
open "FiraCode"/*.ttf
echo "Instala FiraCode en FontBook"

# Meslo LG — Andre Berg (repo ZIP, fonts en dist/)
curl -LO "https://github.com/andreberg/Meslo-Font/archive/master.zip"
unzip -q "master.zip" -d "Meslo-Font/"
open "Meslo-Font/Meslo-Font-master/dist/"*.ttf
echo "Instala Meslo LG en FontBook"
```
