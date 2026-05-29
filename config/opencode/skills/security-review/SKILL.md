---
name: security-review
description: Security audit methodology covering OWASP Top 10, authentication patterns, input validation, dependency auditing, and threat modeling.
---

## Security Review Checklist

### 1. OWASP Top 10 (2025)

| # | Category | Check |
|---|----------|-------|
| A01 | Broken Access Control | IDOR, missing auth checks, privilege escalation |
| A02 | Cryptographic Failures | Weak algorithms, hardcoded keys, plaintext storage |
| A03 | Injection | SQL, NoSQL, XSS, command injection, LDAP |
| A04 | Insecure Design | Missing rate limits, no threat modeling |
| A05 | Security Misconfiguration | Default creds, open S3 buckets, verbose errors |
| A06 | Vulnerable Components | Outdated deps, known CVEs |
| A07 | Auth Failures | Weak passwords, no MFA, session fixation |
| A08 | Data Integrity Failures | Unsafe deserialization, unsigned updates |
| A09 | Logging Failures | Missing audit trail, no alerting |
| A10 | SSRF | Unvalidated URLs, internal network access |

### 2. Authentication & Session Management

```typescript
// GOOD: Token validation
function validateToken(token: string): JwtPayload {
  return jwt.verify(token, SECRET, {
    algorithms: ['RS256'],
    issuer: 'auth.service',
    audience: 'api.service',
    clockTimestamp: Math.floor(Date.now() / 1000),
  })
}

// GOOD: Short-lived access tokens + refresh rotation
const ACCESS_TTL = '15m'
const REFRESH_TTL = '7d'

// GOOD: Rate limit auth endpoints
app.post('/auth/login', rateLimit({ max: 5, window: '15m' }), loginHandler)
```

### 3. Input Validation

```typescript
// GOOD: Schema validation at boundary
import { z } from 'zod'

const createUserSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100),
  role: z.enum(['user', 'admin']).default('user'),
})

// Validate before processing
app.post('/users', (req, res) => {
  const parsed = createUserSchema.safeParse(req.body)
  if (!parsed.success) return res.status(400).json({ error: parsed.error })
  // ...
})
```

### 4. SQL Injection Prevention

```typescript
// BAD
db.query(`SELECT * FROM users WHERE id = ${req.params.id}`)

// GOOD: Parameterized queries
db.query('SELECT * FROM users WHERE id = $1', [req.params.id])

// GOOD: ORM with query builder
await User.query().where('id', req.params.id).first()
```

### 5. XSS Prevention

```typescript
// BAD: dangerouslySetInnerHTML with user input
<div dangerouslySetInnerHTML={{ __html: userInput }} />

// GOOD: Sanitize
import DOMPurify from 'dompurify'
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userInput) }} />

// GOOD: Content Security Policy
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
    styleSrc: ["'self'", "'unsafe-inline'"],
  },
}))
```

### 6. CSRF Protection

```typescript
// Double-submit cookie pattern
app.use(csrf({ cookie: { httpOnly: true, secure: true, sameSite: 'strict' } }))

// Or: SameSite cookies + Origin header validation
app.use((req, res, next) => {
  const origin = req.headers.origin
  if (origin && !ALLOWED_ORIGINS.includes(origin)) {
    return res.status(403).json({ error: 'FORBIDDEN' })
  }
  next()
})
```

### 7. Dependency Audit

```bash
# Check for known vulnerabilities
npm audit --production
pnpm audit --prod

# Check for compromised packages
npq install <package> --dry-run

# Lockfile integrity
npx lockfile-lint --path package-lock.json --type npm --validate-https
```

### 8. Security Headers

```typescript
import helmet from 'helmet'

app.use(helmet())
// Sets: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection,
//       Strict-Transport-Security, Content-Security-Policy, etc.
```

### 9. Secrets Management

```typescript
// BAD: Hardcoded
const API_KEY = 'sk-live-abc123'

// GOOD: Environment with validation
const API_KEY = z.string().min(1).parse(process.env.API_KEY)

// BEST: Vault reference
const API_KEY = await vault.read('secret/data/api', 'key')
```

### 10. Threat Model (STRIDE)

| Threat | Property | Example |
|--------|----------|---------|
| Spoofing | Authentication | Fake JWT, stolen session |
| Tampering | Integrity | Modified API payload |
| Repudiation | Non-repudiation | No audit trail |
| Info Disclosure | Confidentiality | Exposed logs, leaking PII |
| Denial of Service | Availability | No rate limits |
| Elevation of Privilege | Authorization | IDOR, role manipulation |

## Rules

- Every endpoint: auth check + input validation + rate limit.
- No secrets in code, ever. Use vault references.
- Parameterized queries. No string interpolation in SQL.
- CSP headers on all responses.
- Audit trail for state-changing operations.
- Fail closed: deny by default, allow explicitly.
- OWASP Top 10 as minimum bar.
