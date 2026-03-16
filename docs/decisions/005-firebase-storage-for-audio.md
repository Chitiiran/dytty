# ADR-005: Firebase Storage for Audio (Over Google Cloud Storage)

## Status
Accepted

## Context
The daily call feature records audio that needs to be stored in the cloud. The ROADMAP.md originally specified Google Cloud Storage (GCS) for "more control, lifecycle policies, cheaper tiers." However, `AudioStorageService` was implemented using `firebase_storage` and already works with Firebase Auth integration.

Two options were evaluated:
1. **Firebase Storage** — already implemented, integrated with Firebase Auth rules, simple SDK.
2. **Google Cloud Storage** — more granular lifecycle policies, cheaper archive tiers, but requires separate auth/CORS setup and a Cloud Function or service account for uploads.

## Decision
Keep Firebase Storage for audio uploads. The benefits of GCS (lifecycle policies, cheaper storage tiers) are negligible at dogfooding scale (single user, ~10 minutes of audio per day). Firebase Storage's auth integration and existing implementation provide immediate value.

## Consequences
- No code changes needed — `AudioStorageService.uploadCallAudio()` works as-is.
- Audio files are stored at `users/{uid}/calls/{date}/{timestamp}.pcm` with Firebase Auth rules controlling access.
- At scale (many users, long retention), migrating to GCS for lifecycle policies and cold storage tiers may become worthwhile. This migration would only require changing `AudioStorageService` internals — the interface stays the same.
- Cost at dogfooding scale: ~$0.001/day (negligible).
