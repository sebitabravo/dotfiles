---
name: fuzzing-primer
description: Fuzzing techniques, parameter discovery, and vulnerability hunting with AFL++, ffuf, Burp Suite, and custom fuzzers for web and binary targets.
---

## Web Fuzzing

### Directory & File Discovery (ffuf)

```bash
# Directory brute-force
ffuf -u https://target.com/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt -mc 200,301,302,403

# With filtering
ffuf -u https://target.com/FUZZ -w wordlist.txt -mc 200 -fs 1234 -fc 403

# Recursive
ffuf -u https://target.com/FUZZ -w wordlist.txt -recursion -recursion-depth 2

# Extension fuzzing
ffuf -u https://target.com/index.FUZZ -w extensions.txt -mc 200

# Subdomain discovery
ffuf -u https://FUZZ.target.com -w subdomains.txt -mc 200,301 -H "Host: FUZZ.target.com"

# Parameter fuzzing
ffuf -u https://target.com/api/users?FUZZ=value -w params.txt -mc 200 -fs 5432
```

### API Fuzzing

```bash
# Endpoint discovery
ffuf -u https://api.target.com/v1/FUZZ -w api_endpoints.txt -mc 200,201,401,403

# Method fuzzing
for method in GET POST PUT PATCH DELETE OPTIONS; do
  curl -s -o /dev/null -w "$method %{http_code}\n" -X $method https://api.target.com/v1/users
done

# IDOR testing
for id in $(seq 1 100); do
  code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "https://api.target.com/v1/users/$id")
  echo "$id: $code"
done
```

### POST Data Fuzzing

```bash
# JSON body fuzzing
ffuf -u https://api.target.com/v1/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"FUZZ"}' \
  -w passwords.txt \
  -mc 200 \
  -fr "token"

# SQL injection testing
ffuf -u https://target.com/search \
  -d "q=FUZZ" \
  -w sqli_payloads.txt \
  -mc 200,500 \
  -fs 1234
```

## Binary Fuzzing (AFL++)

### Setup

```bash
# Build AFL++
git clone https://github.com/AFLplusplus/AFLplusplus && cd AFLplusplus
make distrib
sudo make install

# Instrument target
export AFL_USE_ASAN=1  # AddressSanitizer
CC=afl-clang-fast CXX=afl-clang-fast++ ./configure
make
```

### Basic Fuzzing

```bash
# Create seed corpus
mkdir -p input
echo "sample input 1" > input/test1
echo "sample input 2" > input/test2

# Run fuzzer
afl-fuzz -i input -o output -m none -- ./target_binary @@

# With dictionary
afl-fuzz -i input -o output -x dict.dict -- ./target_binary @@
```

### Persistent Mode

```c
// target.c
#include <stdio.h>
#include <stdlib.h>

__AFL_FUZZ_INIT();

int main() {
    __AFL_INIT();
    unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;

    while (__AFL_LOOP(10000)) {
        int len = __AFL_FUZZ_TESTCASE_LEN;
        // Process buf[0..len-1]
        parse(buf, len);
    }
    return 0;
}
```

## Coverage-Guided Fuzzing

### libFuzzer (C/C++)

```c
// fuzz_target.c
#include <stdint.h>
#include <stddef.h>

extern int parse(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    parse(data, size);
    return 0;
}
```

```bash
# Build and run
clang -fsanitize=fuzzer,address -o fuzz_target fuzz_target.c parse.c
./fuzz_target -max_len=1024 -jobs=4 corpus/
```

### Go Fuzzing (native)

```go
func FuzzParser(f *testing.F) {
    f.Add("valid input")
    f.Add("edge case 1")

    f.Fuzz(func(t *testing.T, input string) {
        result, err := Parse(input)
        if err != nil {
            return // Expected error, not a crash
        }
        // Verify invariants
        _ = result
    })
}
```

```bash
go test -fuzz=FuzzParser -fuzztime=30s
```

### Python (Atheris)

```python
import atheris
import sys

@atheris.instrument_func
def test_one_input(data):
    fdp = atheris.FuzzedDataProvider(data)
    try:
        input_str = fdp.ConsumeUnicode(100)
        parse(input_str)
    except ValueError:
        pass  # Expected, not a crash

if __name__ == "__main__":
    atheris.Setup(sys.argv, test_one_input)
    atheris.Fuzz()
```

## Mutation Strategies

- Bit flipping: toggle random bits
- Byte flipping: toggle random bytes
- Boundary values: 0, -1, MAX_INT, MIN_INT
- Format strings: `%s`, `%n`, `%x`
- Known interesting values: `0xff`, `0x00`, long strings

## Rules

- Start with common wordlists (SecLists). Move to targeted lists based on findings.
- Filter out false positives with `-fc` and `-fs`.
- Recursion for directory fuzzing (depth 2-3).
- Always fuzz with auth tokens — test IDOR and privilege escalation.
- AddressSanitizer for binary fuzzing (catches memory corruption).
- Seed corpus matters. Real inputs > random data.
- Monitor crash directories. Triage with debugger.
- Rate limit to avoid DoS. This is testing, not attacking.
