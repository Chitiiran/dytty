# ADR-003: Trunk-Based Development over Gitflow

## Status
Accepted

## Context
The project started with a Gitflow-style branch model using a `develop` integration branch. At the current team size (solo/small-team), the extra merge from `develop` to `main` added overhead without providing value. Release branches and hotfix branches were ceremony without benefit.

## Decision
Adopt trunk-based development. Feature branches target `main` directly. CI gates protect main on every pull request:

- Static analysis (`flutter analyze`)
- All tests (unit, widget, golden)
- Coverage threshold (ratcheting from 40% toward 100%)
- Format check (`dart format`)
- Auto-deploy to Firebase Hosting on merge

## Consequences
- Simpler workflow -- one merge instead of two per feature.
- Faster delivery -- changes reach production immediately after merge.
- No release branch ceremony needed at current scale.
- Risk of broken main is mitigated by comprehensive CI gates.
- Can adopt `develop` + release branches later if team grows or release coordination becomes necessary.
