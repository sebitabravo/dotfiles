---
name: code-review-pro
description: Comprehensive code review covering security vulnerabilities, performance bottlenecks, best practices, and refactoring opportunities. Use when user requests code review, security audit, or performance analysis.
---

# Code Review Pro

Deep code analysis covering security, performance, maintainability, and best practices.

## When to Use This Skill

Activate when the user:
- Asks for a code review
- Wants security vulnerability scanning
- Needs performance analysis
- Asks to "review this code" or "audit this code"
- Mentions finding bugs or improvements
- Wants refactoring suggestions
- Requests best practice validation

---

## CRITICAL: False Positive Filtering

**BEFORE reporting any issue, verify it actually matters.** Many findings that seem like vulnerabilities are actually low-risk or false positives.

### Automatically Exclude (Do NOT Report)

| Category | Why Excluded |
|----------|--------------|
| Generic " Denial of Service" without concrete impact | DoS is theoretical unless you show specific resource exhaustion |
| Rate limiting missing | Only a vulnerability if there's evidence of actual abuse potential |
| Generic "input validation" without proven attack vector | Most apps need validation, not all are exploitable |
| Information disclosure in error messages | Only if it reveals credentials, keys, or PII |
| Missing security headers | Only critical if the app handles sensitive data |
| HTTP to HTTPS redirects | Not a vulnerability in modern browsers |
| Missing CSRF tokens in GET requests | Only POST/PUT/DELETE matter for state-changing ops |
| Console.log / print statements | Only security issue if logging secrets |
| Missing rate limiting on public APIs | Only report if no existing rate limiting AND no abuse evidence |

### Questions to Ask Before Reporting

1. **Does this have a REAL attack vector?** (not just theoretical)
2. **What's the actual impact if exploited?** (not hypothetical)
3. **Does the codebase already have mitigations?** (logging, validation, etc.)
4. **Would a real attacker care about this?** (or is it just scanner noise)
5. **Is this framework/environment-specific?** (might not apply)

---

## 1. Security Analysis (Critical Priority)

### SQL Injection — CHECK THESE PATTERNS

**VULNERABLE (report):**
```javascript
// String concatenation in SQL
const query = `SELECT * FROM users WHERE id = '${userId}'`

// String concatenation in ORM
db.query(`SELECT * FROM users WHERE id = ${userId}`)

// Template literals with user input
const sql = `SELECT * FROM products WHERE category = '${category}'`
```

**SAFE (do NOT report):**
```javascript
// Parameterized queries
db.query('SELECT * FROM users WHERE id = ?', [userId])

// ORM built-in methods
User.findById(userId)

// Escaped/validated input
const sanitized = validator.escape(userInput)
db.query('SELECT * FROM users WHERE name = ?', [sanitized])
```

**What to look for:** Search for `query(`, `execute(`, `raw(`, `sql`, `SELECT`, `INSERT`, `UPDATE`, `DELETE` with `${`, `` ` ${ ``, or `'+` patterns.

---

### Cross-Site Scripting (XSS) — CHECK THESE PATTERNS

**VULNERABLE (report):**
```javascript
// Direct HTML insertion
element.innerHTML = userInput
element.outerHTML = userInput

// React dangerouslySetInnerHTML
<div dangerouslySetInnerHTML={{__html: userContent}} />

// Angular/bypass sanitization
DomSanitizer.bypassSecurityTrustHtml(html)

document.write(userInput)
eval(userInput)
```

**SAFE (do NOT report):**
```javascript
// React default (safe)
element.textContent = userInput

// Framework sanitization
<div>{userInput}</div>

// Output encoding
escapeHtml(userInput)
```

**What to look for:** `innerHTML`, `outerHTML`, `dangerouslySetInnerHTML`, `document.write`, `eval`, `v-html` (Vue), `bypassSecurityTrust`.

---

### Authentication & Authorization — CHECK THESE PATTERNS

**VULNERABLE (report):**
```javascript
// Missing authentication check
app.get('/api/users', (req, res) => {
  // No req.user verification!
  db.query('SELECT * FROM users')
})

// IDOR: User can access other user's data
app.get('/api/orders/:id', (req, res) => {
  const order = db.query('SELECT * FROM orders WHERE id = ?', [req.params.id])
  // Missing: req.user.id === order.user_id check
})

// Weak password hashing
const hash = crypto.createHash('md5').update(password).digest('hex')

// Missing authorization check on admin route
app.delete('/api/admin/users/:id', (req, res) => {
  // No admin role check!
})
```

**SAFE (do NOT report):**
```javascript
// Proper auth check
const user = await authenticate(req.headers.authorization)
if (!user) return res.status(401).send()

// Proper authorization
if (order.user_id !== req.user.id) return res.status(403).send()

// Strong hashing
const hash = await bcrypt.hash(password, 12)

// Role-based access
if (req.user.role !== 'admin') return res.status(403).send()
```

**What to look for:** Missing `if (!req.user`, `if (user.role !==`, direct database queries without ownership checks, weak hashing algorithms.

---

### Command Injection — CHECK THESE PATTERNS

**VULNERABLE (report):**
```javascript
// Shell execution with user input
exec(`git commit -m "${message}"`)
child_process.exec(`ls ${userPath}`)
system(`curl ${url}`)
```

**SAFE (do NOT report):**
```javascript
// Parameterized exec
execFile('git', ['commit', '-m', message])

// No user input in command
exec('git log --oneline')
```

---

### Path Traversal — CHECK THESE PATTERNS

**VULNERABLE (report):**
```javascript
// Direct path from user input
const file = fs.readFile(`./uploads/${req.params.filename}`)

// Path.join without validation
const path = path.join(uploadsDir, filename)
```

**SAFE (do NOT report):**
```javascript
// Validated path
const filename = req.params.filename.replace(/[^a-z0-9.-]/g, '')
const file = fs.readFile(`./uploads/${filename}`)

// path.join with base check
const resolved = path.join(uploadsDir, filename)
if (!resolved.startsWith(uploadsDir)) throw new Error('Invalid path')
```

---

### Hardcoded Secrets — CHECK THESE PATTERNS

**VULNERABLE (report):**
```javascript
// API keys, passwords, tokens in code
const apiKey = 'sk-abcdef1234567890'
const password = 'super_secret_123'
const jwtSecret = 'my-secret-key'

// In environment variables accessed improperly
const token = process.env.API_KEY // OK if used correctly
const hardcoded = 'Bearer sk-live-abc123' // NOT OK
```

**SAFE (do NOT report):**
```javascript
// Using process.env correctly
const apiKey = process.env.STRIPE_API_KEY
const password = await vault.get('db-password')

// Config files that are gitignored
const config = require('./config.local.js') // Assumed to be in .gitignore
```

---

### Insecure Deserialization — CHECK THESE PATTERNS

**VULNERABLE (report):**
```javascript
// Python pickle
data = pickle.loads(userData)

// Node deserialization
const obj = require('unserialize')(userData)

// Java deserialization
ObjectInputStreamois = new ObjectInputStream(inputStream);
User user = (User) ois.readObject();
```

**SAFE (do NOT report):**
```javascript
// JSON (safe)
const data = JSON.parse(userData)

// Using serialization libraries with safeguards
import pickle
data = pickle.loads(userData, allowed_classes=['User'])
```

---

### XXE (XML External Entity) — CHECK THESE PATTERNS

**VULNERABLE (report):**
```javascript
// Python
import xml.etree.ElementTree as ET
tree = ET.parse(userXml)

# Java
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", false);
```

**SAFE (do NOT report):**
```javascript
// Disabled external entities
ET.parse(userXml, parser_target=ET.XMLParser(resolve_entities=False))

// Disabled DTD
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
```

---

### Dependency Vulnerabilities — CHECK THESE PATTERNS

**VULNERABLE (report):**
```json
{
  "dependencies": {
    "lodash": "^4.17.5",
    "express": "^4.16.0"
  }
}
```
**Only report if:**
- Known CVEs with actual exploit code
- Vulnerability affects YOUR usage of the library
- No upgrade path available

**Do NOT report:**
- Old versions without known CVEs
- Dev-only dependencies
- Libraries with known fixes available

---

## 2. Performance Analysis

### N+1 Query Problems

**ISSUE (report):**
```javascript
// N+1: fetches all users, then makes separate query for each order
const users = await db.query('SELECT * FROM users')
for (const user of users) {
  user.orders = await db.query('SELECT * FROM orders WHERE user_id = ?', [user.id])
}
```

**FIXED (do NOT report):**
```javascript
// Single query with JOIN
const users = await db.query(`
  SELECT u.*, o.* FROM users u
  LEFT JOIN orders o ON u.id = o.user_id
`)
```

---

### Memory Leaks

**ISSUE (report):**
```javascript
// Event listener not removed
component.on('data', handler)

// Global mutation
global.state = userData

// Closure capturing large objects
function process() {
  const bigData = loadBigData()
  return function() { return bigData } // Leaks bigData
```

---

### Blocking Operations

**ISSUE (report):**
```javascript
// Synchronous file read in server
const data = fs.readFileSync('/path/to/file')

// Heavy computation in main thread
const result = computeHeavyAlgorithm(data)

// Blocking in async context
await syncDatabaseCall()
```

---

### Missing Indexes

**Only report if:**
- Query shows in slow query log
- EXPLAIN shows full table scan
- Query is on hot path (called frequently)

---

## 3. Code Quality & Maintainability

### Function Length
- **Report if > 50 lines** without good reason
- **Accept:** Complex data transformations with many steps

### Cyclomatic Complexity
- **Report if > 10** (function has 10+ decision points)
- **Accept:** Complex business logic with many conditions

### Code Duplication
- **Report if > 3 identical lines** in different places
- **Accept:** Boilerplate that can't be refactored easily

---

## 4. Bugs and Edge Cases

### Common Logic Errors to Find

```javascript
// Off-by-one
for (let i = 0; i <= arr.length; i++) // Should be < not <=

// Wrong operator
if (user.role = 'admin') // Should be === not =

// Null/undefined handling
const name = user.profile.name // profile could be null

// Race conditions
let counter = 0
// Multiple async operations reading/writing counter without lock
```

---

## 5. Output Format

### MUST follow this format EXACTLY:

```markdown
# Code Review Report

## Severity Summary
- 🔴 Critical: X
- 🟠 High: X
- 🟡 Medium: X
- 🟢 Low: X

---

## 🔴 Critical Issues (Fix Before Merge)

### 1. [Title with file:line]
**Severity:** Critical
**Category:** Security/Performance/Bug/Quality
**Evidence:**
```code
// Show the actual problematic code with line number
```
**Impact:** What actually breaks or leaks
**Why Not False Positive:** [Explain why this is real, not theoretical]
**Fix:**
```code
// Show exact fix
```

---

## 🟠 High Priority Issues

### 2. [Title]
[Same structure]

---

## 🟡 Medium / 🟢 Low Issues

[Grouped, less detail needed]

---

## ✅ Things Done Well
- Praise specific good code
- Don't just criticize

---

## 📋 Recommendations for Future
- Technical debt to address later
- Architecture improvements

---

## 🚦 Verdict
**approve** / **changes-requested** / **block**

Only use **block** if:
- Critical security vulnerability
- Data loss/corruption risk
- Auth bypass
- Required features not implemented
```

---

## Review Workflow

1. **FIRST: Filter false positives** using the table above
2. **SECOND: Check security** (injection, auth, secrets) — highest priority
3. **THIRD: Check correctness** (bugs, logic errors)
4. **FOURTH: Check performance** (N+1, blocking ops)
5. **FIFTH: Check quality** (maintainability, best practices)

**For each finding:**
- Show exact code (not just "the code")
- Show exact fix
- Explain WHY it's a problem
- Verify it's not a false positive

---

## Examples

**User:** "Review this authentication code"
**Response:**
```
Security analysis → auth bypass found at auth.js:42 → missing token validation
Check token handling → JWT signature not verified at line 78
Note missing rate limiting → but don't report (no evidence of abuse)
Provide specific fixes with code
```

**User:** "Find performance issues"
**Response:**
```
N+1 at users.js:15 → loop with DB query per iteration
Missing index evidence: explain query plan
Blocking call at process.js:23 → synchronous file read in async handler
```

**User:** "Audit this PR"
**Response:**
```
Review ALL commits in PR
Security first (injection, auth, secrets)
Then correctness, then performance, then quality
Output in verdict format
```