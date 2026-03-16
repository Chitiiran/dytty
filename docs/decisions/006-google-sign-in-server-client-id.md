# ADR-006: Explicit serverClientId for Google Sign-In

## Status
Accepted

## Context
`google_sign_in_android 6.2+` migrated from the legacy Google Sign-In SDK to
Android's Credential Manager API. The old SDK auto-read the web client ID from
`google-services.json` to request an `idToken`. Credential Manager does not —
it requires the `serverClientId` parameter to be passed explicitly to
`GoogleSignIn()`.

Without it, sign-in fails silently with `PlatformException(sign_in_failed,
ApiException: 10)`. This is not caught at build time or by static analysis.

This broke production sign-in from 2026-03-12 until 2026-03-16 (4 days).

## Decision
Pass `serverClientId` (the Web OAuth client ID from GCP) explicitly when
constructing `GoogleSignIn()` in `auth_service.dart`.

## Consequences
- **Upgrade risk**: Any future upgrade of `google_sign_in` should be tested
  with a real Google Sign-In on a physical device. Automated tests use mocks
  and will not catch this class of failure.
- **Hardcoded value**: The web client ID is now hardcoded in `auth_service.dart`.
  If the Firebase project changes or a new OAuth client is created, this value
  must be updated manually.
- **Multi-environment**: If we add staging/prod Firebase projects, we'll need to
  inject the `serverClientId` per environment (e.g., via `--dart-define`).
