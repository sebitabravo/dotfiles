---
name: inacap
description: >
  Genera documentos academicos formato INACAP en DOCX (python-docx).
  Activar ante: informe, documento word, docx, evaluacion, trabajo academico,
  portada INACAP, entrega universitaria, informe tecnico, proyecto.
---

# INACAP Academic Document Generator — v4

Genera documentos DOCX con formato institucional INACAP.

## Filosofia

3 pilares:

1. **Instrucciones del profesor > todo**
2. **Contenido investigado, no inventado**
3. **Formato institucional INACAP** (esta skill)

---

## Flujo de trabajo

### Paso 1: Recolectar datos

Preguntar (si no estan en el contexto):

| Dato | Ejemplo |
|---|---|
| Carrera | `"Ingenieria en Informatica"` |
| Asignatura | `"Aseguramiento de Calidad"` |
| Titulo | `"Analisis de Calidad ISO 25010 — Zoom"` |
| Subtitulo (opcional) | `""` |
| Profesor | `"<Nombre del profesor>"` |
| Integrantes | `["<Integrante 1>", "<Integrante 2>"]` |
| Fecha | `"Mayo 2026"` |
| Sede | `"INACAP Santiago Centro"` |
| Instrucciones del profesor | pegar texto, adjuntar PDF, o describir |

### Paso 2: Analizar instrucciones

Extraer: secciones exigidas, extension, tipo de informe, metodo de citacion, rubrica.

### Paso 3: Investigar

WebSearch con al menos 3 queries. 5+ fuentes verificables.

### Paso 4: Escribir contenido

Lenguaje formal tercera persona. Cada parrafo: afirmacion + evidencia + analisis.

### Paso 5: Generar DOCX

Script Python que importa de `template.py`.

### Paso 6: Auto-evaluar

Contra rubrica del profesor. Si < 80%, corregir.

---

## Formato del documento — Especificaciones EXACTAS

### Pagina

| Propiedad | Valor |
|---|---|
| Tamano | US Letter (8.5 × 11") |
| Margenes | 2.50 cm todos |
| Header distancia | 0.79 cm |
| Footer distancia | 0.96 cm |
| Orientacion | Portrait |
| Primera pagina | `titlePg` (sin header/footer estandar) |

### Colores institucionales INACAP

| Constante | Hex | Uso |
|---|---|---|
| `INACAP_RED` | `#ed1c24` | Rojo corporativo base |
| `INACAP_DARK` | `#231f20` | Negro corporativo base |
| `COVER_TITLE` | `#C00000` | Titulo en portada |
| `COVER_SUBTITLE` | `#4C4C4C` | Subtitulo, lineas institucionales |
| `COVER_META` | `#404040` | Profesor, integrantes, sede |
| `COVER_DATE` | `#606060` | Fecha de entrega |
| `HEADING1` | `#231f20` | Heading 1 (negro corporativo) |
| `HEADING2` | `#ed1c24` | Heading 2 (rojo INACAP) |
| `HEADING3` | `#404040` | Heading 3 (gris oscuro) |
| `TABLE_HEADER_BG` | `#231f20` | Fondo cabecera tabla |
| `TABLE_HEADER_TEXT` | `#FFFFFF` | Texto cabecera tabla |
| `TABLE_BORDER` | `#BFBFBF` | Bordes de tabla |
| `ROW_ALT_A` | `#FFFFFF` | Fila tabla — blanca |
| `ROW_ALT_B` | `#E7E6E6` | Fila tabla — gris alternada |
| `DIVIDER_RED` | `#ed1c24` | Lineas divisorias |
| `FOOTER_TEXT` | `#666666` | Texto footer |
| `FIGURE_GRAY` | `#595959` | Pie de figura |

**NUNCA usar azules (#1F4E79, #2E74B5, #4472C4) ni verdes. Solo rojo INACAP, negro corporativo, grises y blanco.**

### Tipografia v4 (reglas institucionales INACAP)

**UNICA fuente: Arial**. Interlineado: 1.0 (sencillo) para todo.

| Elemento | Pt | Bold | Color | Alineacion |
|---|---|---|---|---|
| Titulo portada | 16 | Si | `#C00000` | Centro |
| Subtitulo portada | 14 | No | `#4C4C4C` | Centro |
| Profesor | 12 | No | `#404040` | Centro |
| Integrantes | 12 | No | `#404040` | Centro |
| Fecha | 12 | No | `#606060` | Centro |
| Sede | 12 | No | `#404040` | Centro |
| Heading 1 | 14 | Si | `#231f20` | Izquierda |
| Heading 2 | 12 | Si | `#ed1c24` | Izquierda |
| Heading 3 | 12 | Si | `#404040` | Izquierda |
| Heading 4 | 11 | Si | `#404040` | Izquierda |
| Heading 5 | 11 | Si | `#000000` | Izquierda |
| Heading 6 | 11 | Si | `#000000` | Izquierda |
| Body / Normal | 11 | No | `#000000` | Justificado |
| Footer | 10 | No | `#666666` | — |
| Tabla header | 11 | Si | `#FFFFFF` | Centro |
| Tabla datos | 11 | No | `#000000` | Izquierda |
| Bullet points | 11 | No | `#000000` | Justificado |
| Pie de figura | 9 | No (italic) | `#595959` | Centro |

### Heading 1 — con linea divisoria

- 14pt bold `#231f20`
- Borde inferior: single, sz=8, color=`#ed1c24`, space=4
- SpaceBefore=Pt(12), SpaceAfter=Pt(4)

### Portada

Estructura vertical (gold standard validado por usuario):

```
[cover_banner_wide.png — full-width en header de seccion 1, 22.46cm ancho]

(12 lineas en blanco)

TITULO — 16pt bold #C00000 centro
Subtitulo (si hay) — 14pt #4C4C4C centro

(1 linea)

Profesor — 12pt #404040 centro

(1 linea)

Integrante 1 — 12pt #404040 centro
Integrante 2 — 12pt #404040 centro
...

(1 linea)

Fecha — 12pt #606060 centro

(1 linea)

Sede — 12pt #404040 centro
```

Sin labels ("Profesor:", "Integrantes:"). Solo los valores. Sin linea divisoria.

### Header (paginas 2+)

- Logo `inacap_logo.png` a la izquierda, **8.31 cm** ancho
- Linea divisoria inferior: single, sz=6, color=`#ed1c24`, space=4

### Footer (paginas 2+)

- Borde superior: single, sz=4, color=`#BFBFBF`, space=4
- Texto: `"Asignatura."` izquierda, 10pt, `#666666`
- Numero de pagina: derecha via PAGE field

### Tablas

```
┌──────────────────────────────────────┐
│  Header Col 1  │  Header Col 2  │... │ ← #231f20 bg, blanco 11pt bold
├──────────────────────────────────────┤
│  dato 1        │  dato 2        │... │ ← #FFFFFF bg (fila 0)
├──────────────────────────────────────┤
│  dato 3        │  dato 4        │... │ ← #E7E6E6 bg (fila 1)
├──────────────────────────────────────┤
│  dato 5        │  dato 6        │... │ ← #FFFFFF bg (fila 2)
└──────────────────────────────────────┘
```

- 6 bordes: single, sz=4, color=`#BFBFBF`
- Header: `#231f20` bg, texto blanco 11pt bold centrado
- Filas: alternancia `#FFFFFF` / `#E7E6E6`
- Texto celdas: 11pt Arial

---

## Workflow DOCX

### Dependencias

```bash
pip install python-docx
```

### Patron de uso

```python
import sys, os
sys.path.insert(0, os.path.expanduser("~/.claude/skills/inacap"))
from template import create_doc, heading, body, section, table, page_break, figure, save

doc = create_doc(
    carrera="Ingenieria en Informatica",
    asignatura="Aseguramiento de Calidad",
    titulo="Titulo del Informe",
    profesor="Nombre Profesor",
    integrantes=["Persona 1", "Persona 2"],
    fecha="Mayo 2026",
    sede="INACAP Santiago Centro",
)

section(doc, "1. Introduccion", [
    "Parrafo 1...",
    "Parrafo 2...",
], level=1)

section(doc, "2.1 Sub-seccion", [
    "Parrafo 1...",
], level=2)

table(doc, ["Col A", "Col B"], [
    ["v1", "v2"],
    ["v3", "v4"],
])

save(doc, "/ruta/output.docx")
```

### API completa

| Funcion | Descripcion |
|---|---|
| `create_doc(carrera, asignatura, titulo, profesor, integrantes, fecha, sede, subtitulo="")` | Crea documento con portada y headers |
| `insert_toc(doc, levels=3)` | Inserta campo de Tabla de Contenido (actualizar con F9 en Word) |
| `heading(doc, text, level=1)` | Heading jerarquico (1-6) |
| `body(doc, text)` | Parrafo justificado 11pt con spacing |
| `section(doc, title, paragraphs, level=1)` | heading + n parrafos body |
| `bullet(doc, text)` | Bullet point 11pt |
| `bullets(doc, items)` | Lista de bullets |
| `sub_heading(doc, text, color="red")` | Sub-heading coloreado (red/dark) |
| `image(doc, path, width_cm=None, description=None, number=None)` | Inserta imagen centrada con pie de figura opcional |
| `table(doc, headers, rows, col_widths=None)` | Tabla formato INACAP |
| `page_break(doc)` | Salto de pagina |
| `figure(doc, number, description)` | Pie de figura 9pt italic |
| `cite_apa(authors, year, page=None)` | Cita parentetica APA 7. Usa "&" entre autores. Retorna string |
| `cite_apa_narrative(authors, year, page=None)` | Cita narrativa APA 7. Usa "y" entre autores. Retorna string |
| `reference_book(doc, author, year, title, publisher, edition=None)` | Referencia APA 7ma: libro |
| `reference_book_chapter(doc, author, year, chapter_title, editor, book_title, pages, publisher, edition=None)` | Referencia APA 7ma: capitulo de libro |
| `reference_article(doc, author, year, title, journal, volume, issue=None, pages=None, doi=None)` | Referencia APA 7ma: articulo |
| `reference_website(doc, author, year, title, site, url)` | Referencia APA 7ma: pagina web |
| `save(doc, filepath)` | Guardar .docx |

---

## Uso de nuevas funciones

### Tabla de Contenido

Llamar `insert_toc(doc)` justo despues de `create_doc()`. Inserta un campo TOC de Word. Al abrir el documento, seleccionar todo (Ctrl+A) y presionar F9 para generar la tabla.

```python
doc = create_doc(...)
insert_toc(doc)         # ← antes de las secciones
section(doc, "1. Introduccion", [...])
```

### Imagenes

```python
image(doc, "diagrama.png", width_cm=14, description="Arquitectura del sistema", number=1)
# Genera: imagen centrada + "Figura 1: Arquitectura del sistema" abajo
```

### Citas APA 7ma

`cite_apa()` retorna string para intercalar en parrafos (parentetica, usa "&"):

```python
body(doc, f"La calidad del software es fundamental {cite_apa('Pressman', 2020)}.")
body(doc, f"Estudios recientes {cite_apa(['Sommerville', 'Sawyer'], 2022, page=156)} confirman...")
```

`cite_apa_narrative()` para citas narrativas (autor como parte de la oracion, usa "y"):

```python
body(doc, f"Segun {cite_apa_narrative('Pressman', 2020)}, la calidad es fundamental.")
body(doc, f"{cite_apa_narrative(['Sommerville', 'Sawyer'], 2022)} plantean que...")
```

Referencias al final del documento:

```python
heading(doc, "Referencias Bibliograficas", level=1)
reference_book(doc, "Pressman, R.", 2020,
    "Software Engineering: A Practitioner's Approach",
    "McGraw-Hill", edition="9")
reference_article(doc, "Sommerville, I. y Sawyer, P.", 2022,
    "Requirements Engineering: Current Practices", "IEEE Software", "39",
    issue="3", pages="22-31", doi="10.1109/MS.2022.3172917")
reference_book_chapter(doc, "Fernandez, M.", 2021,
    "Calidad en equipos agiles", "Garcia, L. (Ed.)",
    "Ingenieria de Software Moderna", "45-67", "McGraw-Hill")
reference_website(doc, "ISO", 2011,
    "ISO 25010: Systems and software Quality Requirements and Evaluation",
    "ISO", "https://www.iso.org/standard/35733.html")
```

---

## Assets

Ubicacion: `~/.claude/skills/inacap/assets/`

| Archivo | Uso | Ancho |
|---|---|---|
| `inacap_logo.png` | Header paginas 2+ y banner portada | 8.31 cm / 22.46 cm |
| `cover_banner_wide.png` | Header de seccion portada | 22.46 cm |

---

## Citacion APA

Default: APA 7ma Edicion. Si el profesor pide otra cosa, seguir al profesor.

**Cita en texto**: `(Apellido, Ano)` para 1 autor, `(Apellido y Apellido, Ano)` para 2, `(Apellido et al., Ano)` para 3+.

---

## Redaccion academica y detectores de IA

### Contexto

Los detectores de IA (ZeroGPT, GPTZero, Turnitin) tienen **tasas de falsos positivos de 16-20%** en textos academicos en español (PeerJ Computer Science, 2025). El texto academico formal en tercera persona — exactamente lo que INACAP exige — es particularmente propenso a ser mal clasificado porque comparte patrones estadisticos con texto generado por IA: perplejidad baja, estructura predecible, vocabulario formal uniforme.

**La skill NO genera contenido — solo formatea.** Si el contenido lo escribis vos, no deberia haber problema. Pero ciertas practicas de redaccion reducen naturalmente el riesgo de falsos positivos sin comprometer la calidad academica.

### Tecnicas de redaccion que reducen falsos positivos

Estas tecnicas NO son "anti-deteccion" — son buenas practicas de escritura academica que ademas producen texto estadisticamente mas "humano":

1. **Variar longitud de oraciones.** Los detectores marcan la uniformidad extrema como patron "machine-like". Alternar oraciones cortas (10-15 palabras) con largas (25-35 palabras) rompe ese patron.
2. **Evitar conectores mecanicos repetitivos.** "Ademas", "Por otro lado", "Asimismo", "En conclusion" en CADA parrafo dispara alertas. Usar transiciones variadas o ninguna transicion explicita cuando el flujo logico es claro.
3. **Incluir datos, ejemplos y cifras especificas.** El texto generico sin anclaje empirico es la principal señal de IA. Cada afirmacion debe respaldarse con evidencia concreta: numeros, fuentes, casos.
4. **Agregar reflexiones criticas genuinas.** Los LLM no hacen autentica autocrítica. Señalar limitaciones del analisis, reconocer sesgos en las fuentes, o discutir interpretaciones alternativas son marcas humanas dificiles de imitar.
5. **Preservar vocabulario tecnico del dominio.** No reemplazar terminos tecnicos por sinonimos "mas naturales". El vocabulario preciso del campo demuestra conocimiento genuino.
6. **Citar fuentes especificas con contexto.** No solo nombrar autores — explicar POR QUE esa fuente es relevante, QUE limitaciones tiene, COMO se relaciona con otras fuentes.

### Que NUNCA hacer

- **"Humanizadores" de texto**: introducen errores factuales, distorsionan significado tecnico y parecen ocultacion intencional (mas grave que el uso transparente de IA).
- **Parafraseo automatico** para evadir detectores: distorsiona terminos tecnicos y genera inconsistencias entre secciones.
- **Copiar y pegar** texto generado por IA sin revision sustancial.

### Defensa ante falsos positivos

Si un profesor cuestiona la autoria:

1. **Historial de versiones.** Google Docs, Word con control de cambios, o commits Git muestran el proceso de escritura incremental (prueba de autoría humana).
2. **Artefactos del proceso.** Notas de investigacion, borradores, busquedas de WebSearch guardadas, datos recolectados.
3. **Conocimiento demostrable.** Poder explicar oralmente cualquier parte del informe — un LLM no puede defender tu trabajo en persona.

### Postura de la skill

Esta skill es un **asistente de formato**, no un generador de contenido. La investigacion (WebSearch) y la redaccion (parrafos) las hace el usuario. La skill aplica formato INACAP, APA 7ma, tablas, TOC y referencias. Esto es uso etico y transparente de IA — analogo a usar una plantilla de Word, no a que alguien escriba por vos.

---

## Reglas CRITICAS

### Formato
1. **Tipografia**: SIEMPRE Arial. Calibri PROHIBIDO.
2. **Colores**: NUNCA azul. Solo rojo `#ed1c24`, negro `#231f20`, grises, blanco.
3. **Body**: 11pt justificado (regla institucional v4).
4. **H1**: 14pt bold `#231f20` + borde inferior rojo `#ed1c24`.
5. **H2**: 12pt bold `#ed1c24` (rojo INACAP).
6. **Header logo**: 8.31 cm ancho (tamano exacto de referencia).
7. **Footer borde**: `#BFBFBF` gris, NO rojo ni negro.
8. **Footer texto**: `#666666` gris, NO negro.
9. **Tabla header bg**: `#231f20` negro corporativo, NO azul.
10. **Tabla filas alternadas**: `#E7E6E6` gris, NO celeste.
11. **Portada**: sin labels ("Profesor:", "Integrantes:"). Solo valores centrados.
12. **Interlineado**: 1.0 sencillo para todo.
13. **Parrafos consecutivos**: espacio visible (6pt space_after).

### Contenido
- NUNCA inventar datos, estadisticas, o citas.
- NUNCA texto placeholder o lorem ipsum.
- SIEMPRE investigar con WebSearch antes de escribir.
- SIEMPRE lenguaje formal academico tercera persona.
- CADA parrafo de desarrollo = afirmacion + evidencia + analisis.

### Instrucciones del profesor
- Prioridad ABSOLUTA sobre esta skill.
- Si el profesor contradice algo aca → seguir al profesor.
- Siempre preguntar por instrucciones si no fueron proporcionadas.

---

## Archivos de la skill

```
~/.claude/skills/inacap/
├── SKILL.md              # Este archivo
├── template.py           # Generador DOCX (python-docx)
└── assets/
    ├── inacap_logo.png       # Logo header (982×131 px)
    └── cover_banner_wide.png # Banner portada (2550×700 px)
```
