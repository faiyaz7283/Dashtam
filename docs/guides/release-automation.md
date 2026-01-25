# Release Automation Guide

## Overview

Dashtam uses a 3-phase release process that automates version bumps,
CHANGELOG generation, PR creation, tagging, and branch syncing.

**What's automated:**

- Version bump in `pyproject.toml`
- Dependency lockfile update (`uv lock`)
- CHANGELOG generation (auto or custom)
- Release branch creation and PR to development
- PR from development → main
- Git tag creation and GitHub Release
- Branch sync (main → development)

**What's manual:**

- Running the release script (Phase 1)
- Merging Phase 1 PR to development (CI must pass)
- Merging Phase 2 PR to main (triggers Phase 3)
- Running local sync after release (`make release-sync`)

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

1. Pre-flight validation:
   - Prerequisites (git, gh, docker, jq)
   - Git state (clean, on development, up-to-date)
   - Branch sync (development mergeable to main)
   - Release label exists (creates if missing)
2. Version validation (format, increment, no duplicate tag)
3. Commits validation (at least 1 since last release)
4. Milestone validation (if specified)
5. Dev container validation (starts if needed)
6. Updates `pyproject.toml` version
7. Runs `uv lock` in dev container
8. Generates CHANGELOG entry
9. Creates release branch (`release/vX.Y.Z`)
10. Commits and pushes changes
11. Creates PR to `development` with `automated-release` label
12. Enables auto-merge on PR

**You do:** Wait for CI to pass → PR auto-merges to development

---

### Phase 2: Create PR to Main (Automated)

**Trigger:** PR merge to `development` with `automated-release` label

**GitHub Actions does:**

1. Extracts version from branch name
2. Extracts CHANGELOG entry
3. Creates PR from `development` → `main` (NO auto-merge)
4. Adds `automated-release` label
5. Deletes release branch

**You do:** Merge the PR to `main` (after CI passes) → triggers Phase 3

---

### Phase 3: Tag, Release, and Sync (Automated)

**Trigger:** Human merges PR to `main` (push event)

**GitHub Actions does:**

1. Detects release commit (version bump pattern)
2. Creates annotated git tag (`vX.Y.Z`)
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

# After release completes - sync local branches
make release-sync PROJECT=api
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
| Project | `PROJECT=api` | `--project, -p` | Project name (api, terminal, jobs) |
| Version | `VERSION=1.9.4` | `--version, -v` | Version to release (X.Y.Z) |
| Milestone | `MILESTONE="v1.9.4"` | `--milestone, -m` | Validate milestone issues |
| Changelog | `CHANGELOG="..."` | `--changelog, -c` | Custom CHANGELOG content |
| Changelog file | `CHANGELOG_FILE=notes.md` | `--changelog-file` | Read CHANGELOG from file |
| Changelog editor | - | `--changelog-editor` | Open \$EDITOR for CHANGELOG |
| Dry-run | `DRY_RUN=1` | `--dry-run` | Preview changes only |
| Verbose | `VERBOSE=1` | `--verbose` | Show detailed output |
| Skip prompts | `YES=1` | `--yes` | Skip all confirmations |

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
- `uv lock` command (with dry-run if supported)
- Generated CHANGELOG entry
- Git commands that would run
- PR title and body preview

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
   - Up-to-date with remote (not ahead or behind)
3. **Branch sync**:
   - Development is not behind main
   - No merge conflicts between development and main
4. **Release label**: Creates `automated-release` label if missing
5. **Version validation**:
   - Semantic version format (X.Y.Z)
   - New version > current version
   - Valid increment (major, minor, or patch only)
   - No duplicate tag exists
6. **Commits validation**:
   - At least 1 commit since last release
   - Breakdown by type (feat, fix, docs, etc.)
   - Warning if only docs/chore commits
7. **Milestone validation** (if specified):
   - Warns if open issues exist (allows continuation)
8. **Dev container**: Running and accessible (auto-starts if needed)

### Post-change Validation

1. **pyproject.toml**: Version updated correctly
2. **uv.lock**: Lockfile updated and parsable (`uv lock --check`)
3. **CHANGELOG.md**: Valid markdown (no lint violations)

---

## CHANGELOG Generation

The script generates CHANGELOG entries with multiple options:

### Auto-Generation (Default)

Uses a hybrid approach combining issues and commits:

**With milestone:**

```bash
make release VERSION=1.9.4 MILESTONE="v1.9.4"
```

- Fetches all closed issues in milestone "v1.9.4"
- Groups by label (Added, Fixed, Changed, etc.)
- Lists related commits under each issue

**Without milestone:**

```bash
make release VERSION=1.9.4
```

- Fetches issues closed in last 30 days
- Same grouping and formatting

### Custom CHANGELOG Options

**Inline content:**

```bash
./scripts/release.sh -p api -v 1.9.4 --changelog "\$(cat <<'EOF'
### Added
- New feature X (#123)

### Fixed
- Bug fix Y (#124)
EOF
)"
```

**From file:**

```bash
./scripts/release.sh -p api -v 1.9.4 --changelog-file release-notes.md
```

**Using editor:**

```bash
./scripts/release.sh -p api -v 1.9.4 --changelog-editor
# Opens \$EDITOR to write content
```

### Output Format

Issues are grouped by label type:

```markdown
## [1.9.4] - 2026-01-25

### Added

- feat(api): Account Endpoints - 4 Endpoints with Sync Support (#208)
- feat(providers): Alpaca Provider - API Key Authentication (#221)

### Fixed

- fix(cache): Handle cache miss gracefully (#210)

### Documentation

- docs: Update API documentation (#215)
```

### Markdown Linting

CHANGELOG is validated with `markdownlint-cli2`:

- Violations **block the release**
- Script fails if linting errors persist
- Fix with: `make lint-md FILE=CHANGELOG.md`

---

## Error Handling

The script uses **fail-fast** with automatic rollback:

### Automatic Rollback

If any step fails after changes begin:

1. Reverts changes to `pyproject.toml`, `uv.lock`, `CHANGELOG.md`
2. Deletes release branch (if created)
3. Exits with detailed error message

### Common Errors

**Error**: Uncommitted changes

```text
❌ Uncommitted changes detected. Commit or stash first.
   Run: git status
```

**Error**: Not on development branch

```text
❌ Must be on development branch (currently on main)
   Run: git checkout development
```

**Error**: Behind remote

```text
❌ Local development is behind origin/development by 2 commit(s)
   Run: git pull origin development
```

**Error**: Development behind main

```text
❌ Development is behind main by 3 commit(s)

This can happen if:
  1. A hotfix was applied directly to main
  2. A previous release sync failed

To fix:
  git checkout development
  git merge origin/main
  git push origin development
```

**Error**: Invalid version

```text
❌ New version (1.9.2) must be greater than current (1.9.3)
```

**Error**: Dev container not running

```text
❌ Dev container not running: dashtam-api-dev-app
   Try manually: cd ~/dashtam/api && make dev-up
```

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

**Common violations:**

- MD022: Add blank line before/after headings
- MD032: Add blank line before/after lists
- MD031: Add blank line before/after code blocks

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

---

## GitHub Actions Workflows

### Phase 2: release-phase2.yml

**Location**: `.github/workflows/release-phase2.yml` (calls reusable)

**Trigger**:

```yaml
on:
  pull_request:
    types: [closed]
    branches:
      - development
```

**Filter**: Only runs if PR has `automated-release` label AND was merged

**Actions**:

1. Extracts version from branch name (`release/v1.9.4` → `1.9.4`)
2. Extracts CHANGELOG entry
3. Creates PR from `development` → `main` (NO auto-merge)
4. Adds `automated-release` label
5. Deletes release branch

### Phase 3: release-phase3.yml

**Location**: `.github/workflows/release-phase3.yml` (calls reusable)

**Trigger**:

```yaml
on:
  push:
    branches:
      - main
```

**Note**: Uses `push` event because human-initiated merges DO trigger
workflows (unlike GITHUB_TOKEN merges).

**Actions**:

1. Detects release commit (version bump in commit message or pyproject.toml)
2. Creates and pushes annotated git tag (`v1.9.4`)
3. Creates GitHub Release with CHANGELOG content
4. Creates sync branch and PR (main → development)
5. Enables auto-merge on sync PR
6. Removes `automated-release` labels from closed PRs

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
3. **Wait for CI**: Let CI complete before moving to next phase
4. **Monitor automation**: Watch Phase 2 & 3 workflows

### After Release

1. **Verify release**: Check GitHub releases page
2. **Sync local branches**:

   ```bash
   # From meta repo
   make release-sync PROJECT=api

   # Or auto-detect from project directory
   cd ~/dashtam/api
   make -C ~/dashtam release-sync
   ```

   This command:
   - Fetches all remotes and prunes stale branches
   - Compares remote vs local state
   - Updates local `development` branch
   - Deletes merged `release/v*` branches
   - Shows current state summary

3. **Close milestone**: Close milestone on GitHub
4. **Announce**: Notify team of release

---

## Examples

### Standard Release

```bash
cd ~/dashtam/api
make release VERSION=1.9.4
# Wait for Phase 1 PR to auto-merge
# Merge Phase 2 PR to main
# Watch Phase 3 complete
make release-sync
```

### Release with Milestone

```bash
make release VERSION=1.9.4 MILESTONE="v1.9.4"
# Validates all milestone issues are closed
```

### Release with Custom CHANGELOG

```bash
# From file
make release VERSION=1.9.4 CHANGELOG_FILE=release-notes.md

# Inline
./scripts/release.sh -p api -v 1.9.4 -c "### Added
- Feature X (#123)"
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

# Preview (dry-run)
./scripts/release-rollback.sh --project api --version 1.9.4 --dry-run
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
- **Actions**: Creates revert commit on development, closes main PR
- **Impact**: Revert commit in git history

#### Phase 4: Tagged and Released (Manual)

- Release tagged and published on main
- **Actions**: Script provides manual instructions (forward fix recommended)
- **Impact**: Requires manual intervention

**IMPORTANT**: Phase 4 does NOT delete tags/releases. This breaks history
for users who pulled the tag. Create a fix release instead.

---

## FAQ

**Q: Can I cancel a release after starting?**

A: Yes. Use `release-rollback.sh` or manually close the PR and delete
the release branch.

**Q: What if Phase 2 or Phase 3 fails?**

A: Check GitHub Actions logs. Manual intervention may be needed.
The tag and release may be created but sync might fail.

**Q: Why do I need to manually merge the PR to main?**

A: Due to GitHub's security limitation, PRs merged with GITHUB_TOKEN
don't trigger other workflows. Human-initiated merges DO trigger workflows.

**Q: Can I release multiple versions at once?**

A: No, only one release per project at a time. Complete one before starting.

**Q: What if I need to fix the CHANGELOG?**

A: Edit CHANGELOG.md in the release PR before merging.

**Q: Can I provide custom CHANGELOG instead of auto-generation?**

A: Yes. Use `--changelog`, `--changelog-file`, or `--changelog-editor`.

**Q: How do I rollback a release?**

A: Use `./scripts/release-rollback.sh --project api --version X.Y.Z`.
For tagged releases (Phase 4), create a forward fix instead.

---

## Related Documentation

- `~/dashtam/scripts/release.sh` - Release script source
- `~/dashtam/scripts/changelog.sh` - Standalone CHANGELOG generator
- `~/dashtam/scripts/release-rollback.sh` - Rollback script
- `~/dashtam/Makefile` - `release`, `release-sync`, `rollback` targets
- `~/dashtam/WARP.md` - Git workflow and release process
- `.github/workflows/release-phase2-reusable.yml` - Phase 2 reusable workflow
- `.github/workflows/release-phase3-reusable.yml` - Phase 3 reusable workflow

---

**Created**: 2026-01-22 | **Last Updated**: 2026-01-25
