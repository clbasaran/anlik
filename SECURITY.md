# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in **anlık.**, please **do not** open a public GitHub issue. Instead, send a private report:

**Email:** celalba78@icloud.com
**Subject prefix:** `[SECURITY] anlık. —`

Please include:
1. Description of the issue and potential impact
2. Steps to reproduce (if applicable)
3. Affected component (iOS app, Cloud Functions, Firestore rules, etc.)
4. Your suggested fix (if you have one)

I aim to respond within **72 hours** and acknowledge receipt. Confirmed issues will be addressed as quickly as possible — typically within 7 days for high severity, 30 days for medium/low.

## Scope

In scope:
- iOS app (current App Store version + repository HEAD)
- Cloud Functions in `functions/`
- Firestore Security Rules (`StripMate/firestore.rules`)
- Cloud Storage Security Rules (`StripMate/storage.rules`)

Out of scope:
- Vulnerabilities in Firebase, Apple frameworks, or third-party dependencies (please report those upstream)
- Issues requiring physical device access or jailbroken devices
- Self-XSS, clickjacking on non-sensitive pages
- Best-practice recommendations without demonstrated impact

## Bring-Your-Own-Secrets

This repository is published as a **portfolio reference implementation**. It does **not** contain any production secrets, API keys, or service account credentials. To run it end-to-end you need:

- Your own Firebase project (with `GoogleService-Info.plist` and `google-services.json`)
- Your own Apple Developer team (for push, App Check, Sign in with Apple)
- Your own Google Cloud Maps API key (set `MAPS_API_KEY` in `android/gradle.properties`)

A template lives at `android/gradle.properties.example`.

## Defensive Stack

The deployed app uses defense in depth:
- **Firebase App Check** with DeviceCheck (iOS) / Play Integrity (Android) — blocks API calls from non-genuine clients
- **Custom claims-based admin model** — `admin: true` claim required for privileged Firestore operations; not self-elevatable from clients
- **Path-based authorization** in Storage rules — uploaded filenames must start with the uploader's UID
- **Size + content-type limits** on every Storage write
- **Rate limiting** — server-side on comments (10/min), client-side on most write paths (5/min)
- **Content moderation** — Cloud Vision SafeSearch on every uploaded photo
- **KVKK/GDPR cascade delete** — 9-step client + 9-step server, removing all user-linked data
- **Active-user check** — banned/suspended/disabled accounts cannot read or write protected content
- **Field-immutability enforcement** — strip update rules only allow specific field changes
- **Pre-commit secret scanning** — gitleaks + detect-secrets run before every commit

## Disclosure Timeline

I follow a standard responsible disclosure model:
1. Receive report → acknowledge within 72 hours
2. Investigate + reproduce → 7-14 days
3. Develop fix → varies by severity
4. Deploy fix → coordinate with reporter on disclosure timing
5. Public disclosure → with reporter credit (if desired) after fix is live

Thank you for helping keep anlık. and its users safe.
