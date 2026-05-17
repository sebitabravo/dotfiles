---
name: fuzzing-primer
description: >
  Fuzzing methodology for vulnerability discovery. AFL++, libFuzzer, advanced ffuf,
  parameter mutation, protocol fuzzing. Trigger: fuzzing, fuzz, AFL, ffuf advanced,
  parameter discovery, input mutation, coverage-guided.
---

# Fuzzing Primer

Systematic fuzzing methodology to discover vulnerabilities that static scanners miss.

## When to Use

- After initial scan (nuclei/nikto), to go deeper.
- When suspicious parameters exist (ID, file, path, query, body).
- Binaries or libraries with input parsing.
- APIs with complex POST/GET parameters.
- Custom protocols or proprietary file formats.

## Web Fuzzing — Advanced ffuf

### Parameter Discovery

```bash
# Discover GET parameters
ffuf -u 'http://target.com/page?FUZZ=test' \
  -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-words.txt \
  -fc 404 -mc all

# Discover POST parameters
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

## API Fuzzing — OpenAPI/GraphQL Schemas

```bash
# GraphQL introspection → fuzz
# Extract schema, generate mutant queries
graphql-fuzz --endpoint http://target.com/graphql --schema schema.json

# REST API fuzzing with OpenAPI spec
# Mutate each parameter with malicious payloads
cat openapi.json | jq '.paths | keys[]' | while read path; do
  ffuf -u "http://target.com${path}?FUZZ=../../etc/passwd" \
    -w /usr/share/wordlists/seclists/Discovery/Web-Content/api-params.txt
done
```

## Binary Fuzzing — AFL++

### Quick Setup

```bash
# Install
brew install afl-fuzz  # macOS
# or
apt install afl++

# Compile with instrumentation
afl-cc -o target_fuzz target.c

# Create initial corpus
mkdir corpus_in corpus_out
echo "valid_input" > corpus_in/seed1

# Fuzz
afl-fuzz -i corpus_in -o corpus_out -- ./target_fuzz @@
```

### Dictionary-Assisted Fuzzing

```bash
# Create token dictionary for the format
afl-fuzz -i corpus_in -o corpus_out -x tokens.dict -- ./target_fuzz @@
```

### Persistent Mode (faster)

```c
// In the target harness
__AFL_FUZZ_INIT();
while (__AFL_LOOP(10000)) {
  unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;
  size_t len = __AFL_FUZZ_TESTCASE_LEN;
  process_input(buf, len);
}
```

## Fuzzing with libFuzzer

```bash
# Compile target with -fsanitize=fuzzer,address
clang -fsanitize=fuzzer,address -o fuzz_target fuzz_target.c

# Run with corpus
./fuzz_target corpus/ -max_len=4096 -jobs=4
```

## Protocol Fuzzing

### Network Protocol Fuzzing

```bash
# Use boofuzz or spike for TCP/UDP protocols
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
# Mutate DNS queries to find parsing bugs
dns_fuzz --server 10.0.0.53 --domain lab.local --type ALL
```

## Fuzzing Workflow

```
1. Identify Input Surface
   ├── HTTP parameters (query, body, headers, cookies)
   ├── File formats (PDF, PNG, XML, JSON, YAML)
   ├── Protocols (custom TCP/UDP, RPC, gRPC)
   └── CLI arguments

2. Choose Fuzzer
   ├── HTTP params → ffuf / wfuzz
   ├── Files → AFL++ / libFuzzer / honggfuzz
   ├── APIs → schemathesis / graphql-fuzz
   └── Protocols → boofuzz / kitty

3. Create Corpus / Wordlist
   ├── Valid payloads + edge cases
   ├── Format dictionaries
   └── Guided mutations

4. Execute Fuzzing
   ├── 30 min minimum
   ├── Monitor crashes/timeouts
   └── Adjust based on coverage

5. Triaging
   ├── Minimize crashes: afl-tmin
   ├── Verify exploitability
   └── Document PoC
```

## Crash Triaging

```bash
# Minimize crashing input
afl-tmin -i crashing_input -o minimized_input -- ./target @@

# Analyze with ASAN output
# Look for: heap-buffer-overflow, stack-buffer-overflow, use-after-free

# Determine exploitability
gdb ./target -ex "run < minimized_input" -ex "bt" -ex "info registers"
```

## Integration with Vulnerability Hunter

- Phase 2.5 of core loop: after Scan, before Exploit.
- Use advanced ffuf for each endpoint with parameters.
- If a binary or library is found: AFL++ + dictionary.
- Document exploitable crashes in the exploit chain.
- Any crashing input → exploit candidate.

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
