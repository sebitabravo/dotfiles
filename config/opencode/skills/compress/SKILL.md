---
name: compress
description: Auto-skill that compresses markdown files or memory content by removing verbose language while preserving all essential information.
---

## Compression Rules

1. **Remove filler words**: "basically", "essentially", "in order to" → "to", "due to the fact that" → "because".
2. **Shorten phrases**: "at this point in time" → "now", "in the event that" → "if", "a large number of" → "many".
3. **Bullet lists over paragraphs**: Convert verbose paragraphs to concise bullet points.
4. **Merge redundant sentences**: If two sentences say the same thing, keep one.
5. **Remove meta-commentary**: "It's worth noting that", "As you can see", "Interestingly".
6. **Tables over prose**: When comparing or listing attributes, use tables.
7. **Code over English**: If a code example demonstrates the point, let it speak.
8. **Preserve technical accuracy**: Never remove details that affect correctness.

## Example

### Before (98 words)

It is important to note that in order to successfully implement authentication in your application, you will need to make sure that you are following a number of best practices. First and foremost, you should always use HTTPS for all of your endpoints. Additionally, it is essential that you store passwords using a strong hashing algorithm such as bcrypt with a minimum cost factor of 12. Furthermore, you should implement rate limiting on your login endpoints in order to prevent brute force attacks. Finally, make sure to use short-lived JWT tokens with refresh token rotation.

### After (38 words, 61% reduction)

Auth best practices:
- HTTPS on all endpoints
- bcrypt with cost >= 12 for passwords
- Rate limit login endpoints
- Short-lived JWT + refresh token rotation

## Memory File Compression

When compressing memory/CLAUDE.md files:
1. Keep all actionable rules and constraints.
2. Convert examples to inline code if shorter.
3. Merge overlapping sections.
4. Keep links and references.
5. Remove "why" if the rule is self-evident.
6. Target: 50-70% size reduction with zero information loss.
