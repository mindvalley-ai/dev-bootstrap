# 🔐 Git Secrets Handling Guide

This guide explains how to handle secrets safely in Git repositories and what to do if your commit is blocked by secret scanning.

---

## 🚨 Why Was My Commit Blocked?

Your commit was blocked because a potential secret was detected in the files you staged. This protects you and the organization from accidentally leaking sensitive information.

Examples of detected secrets:

- API keys
- Access tokens
- Passwords
- Private keys
- Database URLs
- Cloud credentials

---

## ✅ How to Fix It (Quick Steps)

### 1. Find the File

Look at the error output. It will show you the file and line number containing the secret.

Example:

```
File: config.env
Line: 3
```

---

### 2. Remove the Secret

Edit the file and remove the sensitive value.

❌ Bad:

```env
API_KEY=abcd1234secret
```

✅ Good:

```env
API_KEY=YOUR_API_KEY_HERE
```

Or load it from environment variables instead.

---

### 3. Unstage and Re-stage

After fixing the file, run:

```bash
git reset HEAD <file>
git add <file>
```

Then commit again.

---

## 🔐 Where Should Secrets Be Stored?

Never store secrets in source code.

Use one of the following instead:

- GitHub Secrets (for CI/CD)
- Cloud Secret Manager (AWS / GCP / Azure)
- Vault
- 1Password / Password Manager
- `.env` files (with `.gitignore`)

---

## 🤖 AI Safety Rules

When using AI tools:

❌ Do NOT paste:

- Production secrets
- Customer data
- Access tokens
- Credentials

✅ Always sanitize before sharing.

---

## ⚠️ False Positives

Sometimes safe values may be flagged.

If you believe this is a false positive:

1. Review carefully
2. Add an exception in `.gitleaksignore`
3. Contact Platform/Security for approval

Do NOT bypass checks without permission.

---

## 🚫 Do Not Bypass Protection

Avoid using:

```bash
git commit --no-verify
```

unless explicitly approved. All commits are still scanned in CI.

---

## 🆘 Getting Help

If you are unsure how to fix an issue:

- Check internal documentation
- Ask in your engineering support channel
- Contact Platform/Security

---

## 📚 Best Practices

- Never hardcode secrets
- Rotate exposed credentials immediately
- Use least-privilege access
- Review commits before pushing
- Treat credentials like passwords

---

## ✅ Summary

| Rule             | Action             |
| ---------------- | ------------------ |
| Secret detected  | Remove immediately |
| Need credentials | Use secret manager |
| Unsure           | Ask for help       |
| Using AI         | Sanitize input     |

Protecting secrets protects everyone. Thank you for keeping our codebase secure.
