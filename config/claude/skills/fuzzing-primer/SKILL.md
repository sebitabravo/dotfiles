---
name: fuzzing-primer
description: >
  Fuzzing methodology for vulnerability discovery. AFL++, libFuzzer, ffuf avanzado,
  parameter mutation, protocol fuzzing. Trigger: fuzzing, fuzz, AFL, ffuf advanced,
  parameter discovery, input mutation, coverage-guided.
---

# Fuzzing Primer

Metodología sistemática de fuzzing para descubrir vulnerabilidades que scanners estáticos no encuentran.

## When to Use

- Después del scan inicial (nuclei/nikto), para profundizar.
- Cuando hay parámetros sospechosos (ID, file, path, query, body).
- Binarios o librerías con input parsing.
- APIs con POST/GET parameters complejos.
- Protocolos custom o formatos de archivo propietarios.

## Fuzzing Web — ffuf Avanzado

### Parameter Discovery

```bash
# Descubrir parámetros GET
ffuf -u 'http://target.com/page?FUZZ=test' \
  -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-words.txt \
  -fc 404 -mc all

# Descubrir parámetros POST
ffuf -u 'http://target.com/api/endpoint' \
  -X POST -d 'FUZZ=test' \
  -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-words.txt \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -fc 404 -mc all

# JSON parameter discovery
ffuf -u 'http://target.com/api/graphql' \
  -X POST -d '{"FUZZ":"test"}' \
  -w params.txt -H 'Content-Type: application/json' \
  -fr 'error'
```

### Path Traversal Fuzzing

```bash
# LFI parameter fuzzing
ffuf -u 'http://target.com/download?file=FUZZ' \
  -w /usr/share/wordlists/seclists/Fuzzing/LFI/LFI-Jhaddix.txt \
  -fw 0 -fc 404

# Path traversal depth escalation
for depth in $(seq 1 10); do
  prefix=$(printf '../%.0s' $(seq 1 $depth))
  ffuf -u "http://target.com/file?path=${prefix}FUZZ" \
    -w /usr/share/wordlists/seclists/Fuzzing/LFI/LFI-gracefulsecurity-linux.txt \
    -mr 'root:.*:0:0:'
done
```

### SQLi Fuzzing (Beyond sqlmap)

```bash
# Boolean-based blind detection
ffuf -u 'http://target.com/item?id=FUZZ' \
  -w /usr/share/wordlists/seclists/Fuzzing/SQLi/quick-SQLi.txt \
  -mr 'syntax error|mysql_fetch|ORA-|PostgreSQL|SQLite' \
  -fc 404

# Time-based blind detection
ffuf -u 'http://target.com/item?id=FUZZ' \
  -w sql-time-payloads.txt \
  -t 1 -timeout 10
```

### SSTI Fuzzing

```bash
ffuf -u 'http://target.com/template?name=FUZZ' \
  -w /usr/share/wordlists/seclists/Fuzzing/ssti.txt \
  -mr '49|7777777'
```

## Fuzzing de APIs — Esquemas OpenAPI/GraphQL

```bash
# GraphQL introspection → fuzz
# Extraer schema, generar queries mutantes
graphql-fuzz --endpoint http://target.com/graphql --schema schema.json

# REST API fuzzing con OpenAPI spec
# Mutar cada parámetro con payloads maliciosos
cat openapi.json | jq '.paths | keys[]' | while read path; do
  ffuf -u "http://target.com${path}?FUZZ=../../etc/passwd" \
    -w /usr/share/wordlists/seclists/Discovery/Web-Content/api-params.txt
done
```

## Fuzzing de Binarios — AFL++

### Setup Rápido

```bash
# Instalar
brew install afl-fuzz  # macOS
# o
apt install afl++

# Compilar con instrumentación
afl-cc -o target_fuzz target.c

# Crear corpus inicial
mkdir corpus_in corpus_out
echo "valid_input" > corpus_in/seed1

# Fuzzear
afl-fuzz -i corpus_in -o corpus_out -- ./target_fuzz @@
```

### Dictionary-Assisted Fuzzing

```bash
# Crear diccionario de tokens del formato
afl-fuzz -i corpus_in -o corpus_out -x tokens.dict -- ./target_fuzz @@
```

### Persistent Mode (más rápido)

```c
// En el harness del target
__AFL_FUZZ_INIT();
while (__AFL_LOOP(10000)) {
  unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;
  size_t len = __AFL_FUZZ_TESTCASE_LEN;
  process_input(buf, len);
}
```

## Fuzzing con libFuzzer

```bash
# Compilar target con -fsanitize=fuzzer,address
clang -fsanitize=fuzzer,address -o fuzz_target fuzz_target.c

# Ejecutar con corpus
./fuzz_target corpus/ -max_len=4096 -jobs=4
```

## Fuzzing de Protocolos

### Network Protocol Fuzzing

```bash
# Usar boofuzz o spike para protocolos TCP/UDP
python3 << 'PYEOF'
from boofuzz import *

session = Session(target=Target(connection=SocketConnection("192.168.1.100", 9999)))
s_initialize("fuzz_request")
s_string("GET")
s_delim(" ")
s_string("/index.html")
s_delim(" ")
s_string("HTTP/1.1")
session.connect(s_get("fuzz_request"))
session.fuzz()
PYEOF
```

### DNS Fuzzing

```bash
# Mutar queries DNS para encontrar parsing bugs
dns_fuzz --server 10.0.0.53 --domain lab.local --type ALL
```

## Fuzzing Workflow

```
1. Identificar Input Surface
   ├── Parámetros HTTP (query, body, headers, cookies)
   ├── Formatos de archivo (PDF, PNG, XML, JSON, YAML)
   ├── Protocolos (TCP/UDP custom, RPC, gRPC)
   └── CLI arguments

2. Elegir Fuzzer
   ├── HTTP params → ffuf / wfuzz
   ├── Archivos → AFL++ / libFuzzer / honggfuzz
   ├── APIs → schemathesis / graphql-fuzz
   └── Protocolos → boofuzz / kitty

3. Crear Corpus / Wordlist
   ├── Payloads válidos + edge cases
   ├── Diccionarios de formato
   └── Mutaciones guiadas

4. Ejecutar Fuzzing
   ├── 30 min mínimo
   ├── Monitorizar crashes/timeouts
   └── Ajustar según cobertura

5. Triaging
   ├── Minimizar crashes: afl-tmin
   ├── Verificar exploitabilidad
   └── Documentar PoC
```

## Crash Triaging

```bash
# Minimizar input que crashea
afl-tmin -i crashing_input -o minimized_input -- ./target @@

# Analizar con ASAN output
# Buscar: heap-buffer-overflow, stack-buffer-overflow, use-after-free

# Determinar exploitabilidad
gdb ./target -ex "run < minimized_input" -ex "bt" -ex "info registers"
```

## Integración con Vulnerability Hunter

- Fase 2.5 del core loop: después de Scan, antes de Exploit.
- Usar ffuf avanzado para cada endpoint con parámetros.
- Si se encuentra un binario o librería: AFL++ + dictionary.
- Documentar crashes explotables en la cadena de explotación.
- Todo input que crashea → candidato a exploit.

## Commands Quick Reference

```bash
# Web fuzzing
ffuf -u '<url>' -w <wordlist> -mc all -fc 404 -o results.json

# Binary fuzzing
afl-fuzz -i corpus_in -o corpus_out -m none -- ./target @@

# API fuzzing
ffuf -u '<url>' -X POST -d '{"FUZZ":"test"}' -H 'Content-Type: application/json'

# Crash analysis
afl-tmin -i crash -o minimized -- ./target @@
gdb -batch -ex "run < minimized" -ex "bt" -- ./target
```
