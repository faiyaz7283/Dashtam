# Release Automation Guide

## Overview

Dashtam uses a fully automated 3-phase release process that handles
version bumps, CHANGELOG generation, PR creation, tagging, and branch
syncing.

**What's automated:**

- Version bump in `pyproject.toml`
- Dependency lockfile update (`uv lock`)
- CHANGELOG generation from milestone issues
- Release branch creation and PR to development
- PR from development → main (auto-merge)
- Git tag creation and GitHub Release
- Branch sync (main → development)

**What's manual:**

- Running the release script (Phase 1)
- Merging Phase 1 PR to development (final approval)

---

## Quick Start

### From Project Directory

```bash
cd ~/dashtam/api
make release VERSION=1.9.4
```

### From Meta Repo

```bash
cd ~/dashtam
make release PROJECT=api VERSION=1.9.4
```

### Interactive Mode

```bash
make release PROJECT=api  # Prompts for version bump type
```

---

## The 3-Phase Process

### Phase 1: Preparation (Manual Trigger)

**You run:** `make release VERSION=X.Y.Z`

**Script does:**

1. Validates git state (clean, on development, up-to-date)
2. Validates version format and increment
3. Validates commits since last release
4. Creates release branch (`release/vX.Y.Z`)
5. Updates `pyproject.toml` version
6. Runs `uv lock` in dev container
7. Generates CHANGELOG from milestone issues
8. Commits and pushes changes
9. Creates PR to `development` with `automated-release` label
10. Exits

**You do:** Merge the PR to `development` (after CI passes)

---

### Phase 2: Auto-Create PR to Main (Automated)

**Trigger:** PR merge to `development` with `automated-release` label

**GitHub Actions does:**

1. Extracts version from branch name
2. Extracts CHANGELOG entry
3. Creates PR from `development` → `main`
4. Adds `automated-release` label
5. Enables auto-merge
6. Deletes release branch

**Result:** PR auto-merges when CI passes

---

### Phase 3: Tag, Release, and Sync (Automated)

**Trigger:** PR merge to `main` with `automated-release` label

**GitHub Actions does:**

1. Extracts version from PR title
2. Creates git tag (`vX.Y.Z`)
3. Creates GitHub Release with CHANGELOG
4. Creates sync PR (main → development)
5. Enables auto-merge on sync PR
6. Removes `automated-release` labels

**Result:** Release published, branches synced

---

## Command Reference

### Makefile Wrapper

All commands run from meta repo (`~/dashtam`):

```bash
# Basic usage
make release PROJECT=api VERSION=1.9.4

# Auto-detect project from current directory
cd ~/dashtam/api
make release VERSION=1.9.4

# Interactive version selection
make release PROJECT=api

# With milestone validation
make release PROJECT=api VERSION=1.9.4 MILESTONE="v1.9.4"

# Dry-run (preview without changes)
make release PROJECT=api VERSION=1.9.4 DRY_RUN=1

# Verbose output (show CHANGELOG, commands)
make release PROJECT=api VERSION=1.9.4 VERBOSE=1

# Skip confirmations
make release PROJECT=api VERSION=1.9.4 YES=1

# Combine flags
make release PROJECT=api VERSION=1.9.4 DRY_RUN=1 VERBOSE=1
```

### Direct Script Usage

For advanced options:

```bash
cd ~/dashtam
./scripts/release.sh --help

# Examples
./scripts/release.sh --project api --version 1.9.4
./scripts/release.sh --project api --version 1.9.4 --milestone "v1.9.4"
./scripts/release.sh --project api --version 1.9.4 --dry-run --verbose
```

---

## Available Options

| Option | Makefile | Script | Description |
| ------ | -------- | ------ | ----------- |
| Project | `PROJECT=api` | `--project api` | Project name |
| Version | `VERSION=1.9.4` | `--version 1.9.4` | Version |
| Milestone | `MILESTONE="v1.9.4"` | `--milestone "v1.9.4"` | Validate |
| Dry-run | `DRY_RUN=1` | `--dry-run` | Preview |
| Verbose | `VERBOSE=1` | `--verbose` | Detailed output |
| Skip prompts | `YES=1` | `--yes` | Skip prompts |

### Flag Combinations

Flags are independent and can be combined:

```bash
# Recommended for testing
make release VERSION=1.9.4 DRY_RUN=1 VERBOSE=1

# Automated with detailed logs
make release VERSION=1.9.4 YES=1 VERBOSE=1

# Full automation preview
make release VERSION=1.9.4 DRY_RUN=1 YES=1 VERBOSE=1
```

---

## Version Bump Selection

When version is not specified, the script prompts for bump type:

```bash
make release PROJECT=api

# Prompts:
# Current version: 1.9.3
# 
# Version bump options:
#   1) major  (2.0.0)
#   2) minor  (1.10.0)
#   3) patch  (1.9.4)
#   4) custom (specify version)
# 
# Select bump type [1-4]:
```

---

## Dry-Run Mode

Preview all changes without executing:

```bash
make release VERSION=1.9.4 DRY_RUN=1
```

**Shows:**

- Validation results
- Version changes in `pyproject.toml`
- `uv lock` command (or dry-run if supported)
- Generated CHANGELOG entry
- Git commands that would run
- PR creation details

**Does NOT:**

- Modify any files
- Create branches
- Push to remote
- Create PRs

---

## Validation Checks

The script performs comprehensive validation before making changes:

### Pre-flight Validation

1. **Prerequisites**: git, gh CLI, docker, jq
2. **Git state**:
   - Clean working directory (no uncommitted changes)
   - On `development` branch
   - Up-to-date with remote
3. **Version validation**:
   - Semantic version format (X.Y.Z)
   - New version > current version
   - Valid increment (major, minor, or patch)
   - No duplicate tag exists
4. **Commits validation**:
   - At least 1 commit since last release
   - Breakdown by type (feat, fix, docs, etc.)
5. **Milestone validation** (if specified):
   - No open issues in milestone
6. **Dev container**: Running and accessible

### Post-change Validation

1. **pyproject.toml**: Version updated correctly
2. **uv.lock**: Lockfile updated and parsable
3. **CHANGELOG.md**: Valid markdown (no lint violations)

---

## CHANGELOG Generation

The script automatically generates CHANGELOG entries from milestone issues.

### Source

**With milestone:**

```bash
make release VERSION=1.9.4 MILESTONE="v1.9.4"
```

- Fetches all closed issues in milestone "v1.9.4"

**Without milestone:**

```bash
make release VERSION=1.9.4
```

- Fetches issues closed in last 30 days

### Format

Issues are grouped by label type:

```markdown
## [1.9.4] - 2026-01-22

### Features

- feat(api): Account Endpoints - 4 Endpoints with Sync Support (#208)
- feat(providers): Alpaca Provider - API Key Authentication (101 tests) (#221)

### Bug Fixes

- fix(cache): Handle cache miss gracefully (#210)

### Documentation

- docs: Update API documentation (#215)
```

### Markdown Linting

CHANGELOG is validated with `markdownlint-cli2`:

- Violations **block the release**
- Automatically adds proper blank lines (MD022, MD032)
- Script fails if linting errors persist

---

## Error Handling

The script uses **fail-fast** with automatic rollback:

### Automatic Rollback

If any step fails after changes begin:

1. Reverts changes to `pyproject.toml`, `uv.lock`, `CHANGELOG.md`
2. Deletes release branch (if created)
3. Exits with error message

### Common Errors

**Error**: Uncommitted changes

```text
❌ Uncommitted changes detected. Commit or stash first.
   Run: git status
```

**Fix**: Commit or stash your changes

**Error**: Not on development branch

```text
❌ Must be on development branch (currently on main)
   Run: git checkout development
```

**Fix**: Switch to development

**Error**: Behind remote

```text
❌ Local development is behind origin/development by 2 commit(s)
   Run: git pull origin development
```

**Fix**: Pull latest changes

**Error**: Invalid version

```text
❌ New version (1.9.2) must be greater than current (1.9.3)
```

**Fix**: Use correct version

**Error**: Dev container not running

```text
❌ Dev container not running: dashtam-api-dev-app
   Try manually: cd ~/dashtam/api && make dev-up
```

**Fix**: Start dev environment

---

## Troubleshooting

### Script hangs or fails

**Check dev container:**

```bash
cd ~/dashtam/api
make dev-status
make dev-logs
```

**Manually run uv lock:**

```bash
cd ~/dashtam/api
make dev-shell
# Inside container:
cd /app && uv lock
```

### CHANGELOG has lint errors

**Lint manually:**

```bash
cd ~/dashtam/api
make lint-md FILE=CHANGELOG.md
```

**Fix violations:**

- Add blank lines before/after headings
- Add blank lines before/after lists
- Add language identifiers to code blocks

### Release branch already exists

**Delete old branch:**

```bash
git branch -D release/v1.9.4
git push origin --delete release/v1.9.4
```

### Milestone has open issues

Script warns but allows continuation:

```text
⚠️  Milestone 'v1.9.4' has open issues
Continue anyway? (y/n):
```

**Options:**

1. Close or move issues, then retry
2. Continue anyway (issues won't block)
3. Cancel and fix milestone

---

## GitHub Actions Workflows

### Phase 2: release-phase2.yml

**Location**: `.github/workflows/release-phase2.yml`

**Trigger**:

```yaml
on:
  pull_request:
    types: [closed]
    branches:
      - development
```

**Filter**: Only runs if PR has `automated-release` label

**Actions**:

1. Extracts version from branch name (`release/v1.9.4` → `1.9.4`)
2. Extracts CHANGELOG entry
3. Creates PR from `development` → `main`
4. Enables auto-merge
5. Deletes release branch

### Phase 3: release-phase3.yml

**Location**: `.github/workflows/release-phase3.yml`

**Trigger**:

```yaml
on:
  pull_request:
    types: [closed]
    branches:
      - main
```

**Filter**: Only runs if PR has `automated-release` label

**Actions**:

1. Extracts version from PR title
2. Creates and pushes git tag (`v1.9.4`)
3. Creates GitHub Release with CHANGELOG
4. Creates sync branch and PR (main → development)
5. Enables auto-merge on sync PR
6. Removes `automated-release` labels

---

## Best Practices

### Before Release

1. **Close milestone issues**: All issues in milestone should be closed
2. **Test locally**: Run `make verify` to ensure tests pass
3. **Review commits**: Check `git log` since last tag
4. **Update docs**: Ensure documentation is current

### During Release

1. **Use dry-run first**: Preview changes with `DRY_RUN=1`
2. **Review CHANGELOG**: Check generated CHANGELOG in PR
3. **Wait for CI**: Let CI complete before merging
4. **Monitor automation**: Watch Phase 2 & 3 workflows

### After Release

1. **Verify tag**: Check GitHub releases page
2. **Pull changes**: Update local branches

   ```bash
   git checkout development && git pull
   git checkout main && git pull
   git fetch --tags
   ```

3. **Close milestone**: Close milestone on GitHub
4. **Announce**: Notify team of release

---

## CI/CD Integration

### GitHub Actions Status

Check workflow runs:

```bash
gh run list --limit 5
gh run view <run-id>
gh run watch  # Watch latest run
```

### Auto-Merge Requirements

For auto-merge to work:

1. **Repository setting**: Auto-merge must be enabled
2. **Branch protection**: CI checks must be configured
3. **CI status**: All required checks must pass

---

## Examples

### Standard Release

```bash
cd ~/dashtam/api
make release VERSION=1.9.4
# Review and merge PR
# Watch automation complete
```

### Release with Milestone

```bash
make release VERSION=1.9.4 MILESTONE="v1.9.4"
# Validates all milestone issues are closed
```

### Test Release (Dry-Run)

```bash
make release VERSION=1.9.4 DRY_RUN=1 VERBOSE=1
# Preview all changes without executing
```

### Automated Release (CI)

```bash
make release VERSION=1.9.4 YES=1
# Skip all prompts for CI/CD pipelines
```

### Multi-Project Release

```bash
# Terminal project
cd ~/dashtam/terminal
make release VERSION=0.3.0

# Jobs project
cd ~/dashtam/jobs
make release VERSION=0.2.1
```

---

## Rollback Process

### Automatic Rollback Script

The `release-rollback.sh` script handles rollback based on release phase.

**Usage:**

```bash
cd ~/dashtam
./scripts/release-rollback.sh --project api --version 1.9.4

# Force specific phase
./scripts/release-rollback.sh --project api --version 1.9.4 --phase 2

# Skip confirmations
./scripts/release-rollback.sh --project api --version 1.9.4 --yes
```

### Rollback by Phase

#### Phase 1: Release Branch (Easiest)

- Release branch exists but not merged to development
- **Actions**: Deletes local and remote release branch
- **Impact**: None (no commits merged)

#### Phase 2: PR Created (Easy)

- PR to development created but not merged
- **Actions**: Closes PR, deletes release branch
- **Impact**: None (no commits merged)

#### Phase 3: Merged to Development (Moderate)

- Merged to development, but not to main
- **Actions**: Creates revert commit on development, closes main PR if
  exists
- **Impact**: Revert commit in git history

#### Phase 4: Tagged and Released (Manual)

- Release tagged and published on main
- **Actions**: Script provides manual instructions (forward fix recommended)
- **Impact**: Requires manual intervention

**IMPORTANT**: Phase 4 does NOT delete tags/releases. This breaks history
for users who pulled the tag. Create a fix release instead.

### Manual Rollback Commands

**Phase 1 (Manual):**

```bash
cd ~/dashtam/api
git branch -D release/v1.9.4
git push origin --delete release/v1.9.4
```

**Phase 2 (Manual):**

```bash
gh pr close <PR_NUMBER> --comment "Cancelling release" --delete-branch
```

**Phase 3 (Manual):**

```bash
cd ~/dashtam/api
git checkout development
git pull origin development
git revert <RELEASE_COMMIT> --no-edit
git push origin development
```

**Phase 4 (Manual - Forward Fix):**

```bash
# Create fix release
make release VERSION=1.9.5
```

---

## FAQ

**Q: Can I cancel a release after starting?**

A: Yes. Use `release-rollback.sh` or manually close the PR and delete
the release branch.

**Q: What if Phase 2 or Phase 3 fails?**

A: Check GitHub Actions logs. The tag and release may be created,
but sync might fail. Manual intervention may be needed.

**Q: Can I release multiple versions at once?**

A: No, only one release per project at a time. Complete one before starting another.

**Q: What if I need to fix the CHANGELOG?**

A: Edit CHANGELOG.md in the release PR before merging.

**Q: Can I skip CHANGELOG generation?**

A: No, CHANGELOG is always generated. You can edit it in the PR.

**Q: How do I rollback a release?**

A: Use `./scripts/release-rollback.sh --project api --version X.Y.Z`.
For tagged releases (Phase 4), create a forward fix instead.

---

## Related Documentation

- `~/dashtam/scripts/release.sh` - Release script source
- `~/dashtam/scripts/release-rollback.sh` - Rollback script
- `~/dashtam/WARP.md` - Git workflow and release process
- `.github/workflows/release-phase2.yml` - Phase 2 automation
- `.github/workflows/release-phase3.yml` - Phase 3 automation

---

**Created**: 2026-01-22 | **Last Updated**: 2026-01-22
