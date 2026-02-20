# OfcHoursApp Versioning Workflow

## Current Stable Point
- Branch: `main`
- Baseline commit: `a7e5da9`
- Baseline tag: `v0.1.0`

## Daily Development Flow
1. Latest changes:
```bash
git checkout main
git pull
```
2. Create a feature branch:
```bash
git checkout -b codex/<short-feature-name>
```
3. Commit in small chunks:
```bash
git add -A
git commit -m "feat: <what changed>"
```
4. Merge back after local verification:
```bash
git checkout main
git merge --no-ff codex/<short-feature-name>
```

## Release Tagging
Create a tag at each stable release:
```bash
git tag -a v0.1.1 -m "Release v0.1.1"
git push origin v0.1.1
```

## Fast Rollback Options
- Inspect history:
```bash
git log --oneline --decorate -n 20
```
- Compare with a stable tag:
```bash
git diff v0.1.0..HEAD
```
- Temporarily test old version (detached HEAD):
```bash
git checkout v0.1.0
```
- Return to main:
```bash
git checkout main
```

## Commit Message Convention
- `feat:` new capability
- `fix:` bug/crash fix
- `refactor:` internal cleanup
- `chore:` tooling/config/docs

## Recommended Rule
Never keep uncommitted work for long. Commit every meaningful, testable step.
