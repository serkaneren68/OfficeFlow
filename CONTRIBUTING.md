# Contributing

## Branching

- New work must be done on `codex/<feature-name>` branches.
- Keep `main` stable and releasable.

## Commit Convention

- `feat:` new capability
- `fix:` bug/crash fix
- `refactor:` internal cleanup
- `chore:` tooling/config/docs

## Pull Request Rules

- Keep PRs focused and small.
- Add test or validation notes in PR description.
- If UI is changed, include screenshot(s).
- Before PR, run local build:
```bash
xcodebuild -project OfcHoursApp.xcodeproj -scheme OfcHoursApp -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## Release and Rollback

- Tag stable points (`vX.Y.Z`).
- Follow `VERSIONING.md` for release and rollback steps.
