# Dytty -- Release Process

> On-demand release cadence. Releases are cut when a milestone or meaningful chunk of work is ready.

---

## Overview

```
main ── feat ── feat ── feat ──+
                               | cut release branch (when needed)
                               v
                         release/X.Y.Z -- fix -- fix
                               |
                               | all gates pass
                               v
main ───────────────── merge -- tag vX.Y.Z+N -- deploy
```

## Branch Model

| Branch | Purpose | Merges to |
|--------|---------|-----------|
| `main` | Production-ready. Every commit is a release. | -- |
| `release/X.Y.Z` | Release candidate. Only bug fixes allowed. | `main` |
| `feat/*`, `fix/*` | Feature work. Short-lived. | `main` |

## Cutting a Release

### 1. Create release branch
```bash
bash scripts/release.sh 0.2.0
```

This script:
- Verifies you are on `main` with a clean tree
- Pulls latest `main`
- Creates `release/0.2.0` branch
- Bumps version in `pubspec.yaml`
- Commits the version bump

### 2. Push and verify CI
```bash
git push -u origin release/0.2.0
```

The `release-candidate.yml` workflow automatically runs:
- `flutter analyze` + `flutter test` (all)
- Coverage check (min 60%)
- Maestro E2E with `release` tag (all flows)
- Build release APK
- Upload to Firebase App Distribution

### 3. Dogfooding (2-3 days)
- APK distributed to internal testers via Firebase App Distribution
- Bugs filed as GitHub Issues with priority labels
- **P0/P1**: fix on release branch
- **P2/P3**: backlog for next cycle

### 4. Merge to main
When all gates pass and dogfooding is clean:
```bash
gh pr create --base main --title "Release 0.2.0" --body "..."
```

After merge:
```bash
# Clean up
git branch -d release/0.2.0
git push origin --delete release/0.2.0
```

The `deploy.yml` workflow on main push:
- Deploys web build to Firebase Hosting
- Creates git tag `vX.Y.Z`

---

## Quality Gates

### Gate 1: Developer TDD Loop (every save)
- `flutter analyze` (zero issues)
- `flutter test` (unit + widget + golden)
- ~10 seconds total

### Gate 2: PR to `main` (automated CI)
| Check | Blocks merge? |
|-------|---------------|
| `flutter analyze` | Yes |
| `flutter test` (unit + widget + golden) | Yes |
| Coverage >= 60% | Yes |
| Build web | Yes |
| Build APK | Yes |
| Maestro smoke + state flows | Yes |

### Gate 3: Release Candidate (automated, on `release/*` push)
| Check | Blocks release? |
|-------|-----------------|
| All Gate 2 checks | Yes |
| Maestro full suite (smoke + state + release) | Yes |
| Release APK build | Yes |
| App Distribution upload | Automated |

### Gate 4: Internal Dogfooding (manual)
- APK distributed to testers
- 2-3 day window for feedback
- P0/P1 bugs block release

### Gate 5: Production Release (merge to `main`)
- Manual merge after all gates pass
- Auto: deploy web, create git tag

---

## Version Convention

Format: `X.Y.Z+build`
- **X**: Major (breaking changes)
- **Y**: Minor (new features)
- **Z**: Patch (bug fixes)
- **build**: Auto-incremented integer for Firebase

`scripts/release.sh` handles version bumping automatically.

---

## Rollback

### Web (Firebase Hosting)
Firebase Hosting keeps previous deploy history. To rollback:
1. Go to Firebase Console > Hosting > Release history
2. Click "Rollback" on the desired previous version

### Android (Firebase App Distribution)
App Distribution does not support rollback directly. Instead:
1. Find the last-known-good tag: `git tag -l --sort=-creatordate | head -5`
2. Check out that tag: `git checkout v0.1.7+9`
3. Bump only the build number in pubspec.yaml (Android requires higher build number)
4. Re-distribute: `bash scripts/distribute.sh "Rollback to v0.1.7+9"`

---

## Debug Keystore

The project uses a shared debug keystore checked into `android/debug.keystore`.
All builds (local and CI) use this keystore via `build.gradle.kts` signingConfig.
This ensures APK signatures are consistent across machines — testers can update
without reinstalling.

Credentials (standard Android debug defaults):
- Store/key password: `android`
- Key alias: `androiddebugkey`
