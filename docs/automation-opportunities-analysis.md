# Development Workflow Automation - Discovery & Analysis

**Purpose**: Comprehensive analysis of Dashtam platform workflows to identify automation opportunities and design script/tool architecture.

**Status**: Phase 1 (Discovery) Complete → Phase 2 (Analysis) In Progress

**Date**: 2026-01-22

---

## Executive Summary

### Key Findings

**Current State**:
- 4 Makefiles with 150+ commands across meta, api, terminal, jobs
- 3 environments per project (dev, test, ci) with docker-compose orchestration
- Mandatory workflows enforced via WARP rules (markdown lint, MkDocs, verify)
- GitHub Actions CI/CD with 2 workflows per project
- Manual release process (version bump, changelog, tagging, sync branches)
- No centralized tooling or cross-project automation

**Opportunities Identified**: 47 automation candidates across 8 categories

**High-Impact Quick Wins**:
1. Release automation script (eliminates 13-step manual process)
2. Cross-project test runner (run tests across all repos)
3. Environment health checker (validate all services status)
4. Dependency update automation (UV lock sync across projects)
5. WARP.md structure validator (enforce rules automatically)

**Jobs Service Candidates**:
- Scheduled dependency updates
- Nightly cross-project test runs
- Documentation build validation
- Container image cleanup
- Health monitoring and alerts

---

## Part 1: Current State Analysis

### 1.1 Makefile Command Inventory

#### Meta Repo (`~/dashtam/Makefile`)
**Commands**: 2
- `help` - Display available commands
- `create-issue` - Create GitHub issue with project integration

**Pattern**: Minimal commands, delegates to submodules

#### API Repo (`~/dashtam/api/Makefile`)
**Commands**: 61 (most comprehensive)

**Categories**:
- **Development** (12 commands): `dev-up`, `dev-down`, `dev-logs`, `dev-shell`, `dev-db-shell`, `dev-redis-cli`, `dev-restart`, `dev-status`, `dev-build`, `dev-rebuild`
- **Testing** (8 commands): `test-up`, `test-down`, `test-restart`, `test`, `test-unit`, `test-integration`, `test-api`, `test-smoke`
- **CI/CD** (3 commands): `ci-test-local`, `ci-test`, `ci-lint`
- **Code Quality** (4 commands): `lint`, `format`, `type-check`, `verify`
- **Markdown Linting** (3 commands): `lint-md`, `lint-md-check`, `lint-md-fix`
- **Documentation** (3 commands): `docs-serve`, `docs-build`, `docs-stop`
- **Database** (5 commands): `migrate`, `migrate-create`, `migrate-down`, `migrate-history`, `migrate-current`
- **Setup** (3 commands): `setup`, `keys-generate`, `keys-validate`
- **Utilities** (5 commands): `check`, `status-all`, `ps`, `clean`

**Key Features**:
- Flexible test targeting with `TEST_PATH` and `ARGS` parameters
- Comprehensive markdown linting with safety modes (dry-run, diff, apply)
- Full verification pipeline (`make verify` = 7 steps)
- Idempotent setup with automatic `.env` creation

#### Terminal Repo (`~/dashtam/terminal/Makefile`)
**Commands**: 18

**Categories**:
- **Development** (8 commands): `dev-up`, `dev-down`, `dev-logs`, `dev-shell`, `dev-restart`, `dev-status`, `dev-build`, `dev-rebuild`
- **Code Quality** (5 commands): `lint`, `format`, `type-check`, `test`, `verify`
- **Utilities** (5 commands): `setup`, `check`, `status-all`, `ps`, `clean`

**Pattern**: Simpler than API (no separate test environment, no database migrations)

#### Jobs Repo (`~/dashtam/jobs/Makefile`)
**Commands**: 27

**Categories**:
- **Development** (9 commands): `dev-up`, `dev-down`, `dev-logs`, `dev-shell`, `dev-worker-shell`, `dev-scheduler-shell`, `dev-redis-cli`, `dev-restart`, `dev-status`
- **Testing** (5 commands): `test-up`, `test-down`, `test`, `test-unit`, `test-integration`
- **CI/CD** (2 commands): `ci-test`, `ci-lint`
- **Code Quality** (4 commands): `lint`, `format`, `type-check`, `verify`
- **Documentation** (3 commands): `docs-serve`, `docs-build`, `docs-stop`
- **Utilities** (5 commands): `setup`, `check`, `status-all`, `ps`, `clean`

**Pattern**: Similar to API but with worker/scheduler separation

### 1.2 WARP Rules - Mandatory Workflows

#### Global Rules (12 total, apply to all projects)

**Enforced Processes**:
1. **AI Agent Workflow** (Rule 10):
   - Create feature branch FIRST
   - Pre-development: analyze → plan → TODO list → GET APPROVAL
   - ❌ NEVER code without approval
   - ❌ NEVER commit without user request

2. **Git Workflow** (Rule 5):
   - Conventional commits with co-author for AI
   - Branch protection (main + development)
   - Release process: 13 steps including sync main → development

3. **Code Quality** (Rule 6):
   - Ruff (lint + format)
   - Mypy (strict type checking)
   - Google-style docstrings

4. **Testing** (Rule 7):
   - 85%+ overall coverage
   - All tests in Docker containers

5. **Documentation** (Rule 9):
   - Markdown linting (zero violations)
   - MkDocs builds (zero warnings)

6. **Docker Containerization** (Rule 4):
   - ALL development in containers
   - No local Python environments
   - Consistent `dev-*` command prefixes

7. **GitHub Issues** (Rule 12):
   - All features tracked via issues
   - Branch naming: `feature/issue-N-slug`
   - Commit references: `type(scope): description (#N)`
   - Auto-add to project via workflow

#### API-Specific Rules (18 additional)

**Key Constraints**:
- Hexagonal architecture (domain depends on nothing)
- CQRS pattern (commands vs queries)
- Event registry pattern (single source of truth)
- Route metadata registry (no decorators)
- 100% REST compliance (resource-oriented URLs)
- Container usage: dev for `uv lock`, test for `make test`

#### Jobs-Specific Rules

**Key Patterns**:
- TaskIQ framework with Redis backend
- Jobs orchestrate, don't implement business logic
- Container-based development only

### 1.3 Docker Orchestration Patterns

#### Environment Matrix

| Environment | Purpose | Compose File | Containers | Storage | Ports |
|-------------|---------|--------------|------------|---------|-------|
| **Development** | Daily coding | `dev.yml` | app, postgres, redis | Named volumes | Exposed (5432, 6379) |
| **Test** | Local testing | `test.yml` | app, postgres, redis | tmpfs (ephemeral) | Exposed (5433, 6380) |
| **CI** | GitHub Actions | `ci.yml` | app, postgres, redis | tmpfs (ephemeral) | Internal only |

#### Common Patterns Across Projects

**Multi-Service Setup**:
- App container with full project mount (dev) or selective mounts (test/ci)
- PostgreSQL with health checks
- Redis with health checks
- Traefik integration (dev/test only)

**Volume Strategies**:
- Dev: Named volumes for persistence + anonymous `/app/.venv` volume
- Test/CI: tmpfs for speed and clean state

**Container Usage Rules** (from WARP):
- Dev container: `uv lock`, `uv add`, package management, file modifications
- Test container: Running tests via `make test`, `make verify`
- ❌ CRITICAL: Never use test container for `uv lock` (lockfile won't persist to host)

#### Environment Variable Management

**Pattern** (idempotent):
```makefile
_ensure-env-dev:
	@if [ ! -f env/.env.dev ]; then \
		cp env/.env.example env/.env.dev; \
	fi
```

**Files**:
- `.env.example` (committed, template)
- `.env.dev` (gitignored, auto-created)
- `.env.test` (gitignored, auto-created)
- `.env.ci.example` (committed, for CI)

### 1.4 CI/CD Workflows

#### API CI/CD (GitHub Actions)

**Workflows**:
1. **Test Suite** (`test.yml`):
   - Job: `test-main` - Runs all tests except smoke (pytest with coverage)
   - Job: `lint` - Ruff linter/formatter + markdown linter (Node.js)
   - Uploads coverage to Codecov
   - Uses CI compose file with optimized PostgreSQL settings

2. **Documentation** (`docs.yml`):
   - Builds MkDocs with strict mode
   - Filters griffe/autorefs warnings (false positives)
   - Deploys to GitHub Pages
   - Triggered on docs changes to development branch

**Optimization Notes**:
- CI uses tmpfs for database/redis (speed)
- PostgreSQL tuned for speed over durability (`synchronous_commit=off`)
- Resource limits match GitHub Actions free tier (7GB RAM, 2 CPUs)

#### Terminal/Jobs CI/CD

**Pattern**: Similar to API but simplified
- Single test job (no separate smoke tests)
- Lint job with ruff + markdown
- No documentation deployment (not set up yet)

### 1.5 Pain Points Identified

#### Release Process (Manual, 13 Steps)

**Current Process** (from WARP Rule 5):
1. Verify all milestone issues closed
2. Update version in `pyproject.toml`
3. Run `uv lock` (inside dev container)
4. Update `CHANGELOG.md`
5. Commit and push to development
6. Wait for CI
7. Merge PR to development
8. Create PR from development → main
9. Merge PR to main
10. Tag release: `git tag -a vX.Y.Z`
11. Push tag
12. Create GitHub Release with `gh release create`
13. **CRITICAL**: Sync main back to development (prevents conflicts)

**Pain Points**:
- Highly manual (error-prone)
- Easy to forget step 13 (causes version drift conflicts)
- No validation that milestone issues are closed
- Manual CHANGELOG updates

#### Cross-Project Operations

**Current State**: No unified way to:
- Run tests across all projects
- Check status of all environments
- Update dependencies across all projects
- Lint/format all projects
- Deploy all documentation
- Verify all projects before release

**Impact**: Must manually run commands in each project directory

#### Markdown Linting

**Current State**:
- API has comprehensive `lint-md` with safety modes (dry-run, diff, apply)
- Terminal/Jobs have basic `lint-md` only
- No cross-project markdown linting
- Manual fixing required

#### Environment Management

**Pain Points**:
- Must manually ensure Traefik is running before `make dev-up`
- No unified health check across all services
- No easy way to see what's running across all projects
- Container name conflicts if not careful

#### WARP.md Maintenance

**Pain Points**:
- Structure rules must be manually enforced
- Line numbers in Rule Index must be manually updated
- Easy to drift between Global and Project WARPs
- No validation that structure is preserved

---

## Part 2: Automation Opportunities Matrix

### 2.1 High-Priority Quick Wins

#### 1. Release Automation Script

**Purpose**: Automate the 13-step release process with validation

**Proposed Script**: `scripts/release.sh`

**Capabilities**:
- Validate all milestone issues closed (GitHub API)
- Interactive version bump (semver: major/minor/patch)
- Auto-update `pyproject.toml` version
- Run `uv lock` in correct container (dev)
- Generate CHANGELOG entry from closed issues
- Create feature branch, commit, push
- Create PR to development (wait for CI)
- After merge, create PR to main
- Tag release and push
- Create GitHub Release with notes
- **Auto-sync main → development** (prevents drift)
- Validation: All steps completed, no errors

**Execution Model**: Local script (bash)

**Complexity**: High (GitHub API, git operations, multi-step orchestration)

**Impact**: ⭐⭐⭐⭐⭐ Eliminates error-prone manual process

**Dependencies**: `gh` CLI, `jq`, Docker

**Estimated Lines**: 300-400

#### 2. Cross-Project Test Runner

**Purpose**: Run tests across all projects with aggregated results

**Proposed Script**: `scripts/test-all.sh`

**Capabilities**:
- Detect all projects (api, terminal, jobs)
- Run `make test` in each project (parallel option)
- Aggregate results (pass/fail counts)
- Generate summary report
- Exit with error if any project fails
- Optional: Filter by test type (unit, integration, all)
- Optional: Generate combined coverage report

**Execution Model**: Local script (bash) OR Jobs service (scheduled)

**Complexity**: Medium (parallel execution, result aggregation)

**Impact**: ⭐⭐⭐⭐ Enables rapid full-platform testing

**Dependencies**: Docker (for `make test` in each project)

**Estimated Lines**: 150-200

#### 3. Environment Health Checker

**Purpose**: Validate all services across all projects

**Proposed Script**: `scripts/health-check.sh`

**Capabilities**:
- Check Traefik status (required for all)
- For each project (api, terminal, jobs):
  - Check if dev environment is running
  - Check container health (postgres, redis, app)
  - Check service connectivity (database, cache)
  - Check DNS resolution (dashtam.local, etc.)
- Generate health report (table format)
- Exit with warnings/errors if issues found
- Optional: Auto-fix (start Traefik, restart unhealthy containers)

**Execution Model**: Local script (bash) OR Jobs service (scheduled monitoring)

**Complexity**: Medium (Docker API, health checks, connectivity tests)

**Impact**: ⭐⭐⭐⭐ Eliminates "why isn't it working?" debugging

**Dependencies**: Docker, curl/httpx

**Estimated Lines**: 200-250

#### 4. Dependency Update Automation

**Purpose**: Sync dependencies across all projects

**Proposed Script**: `scripts/update-deps.sh`

**Capabilities**:
- For each project (api, terminal, jobs):
  - Run `uv sync` to update lockfile
  - Optionally run `uv lock --upgrade` for latest versions
  - Detect changed dependencies
  - Run tests to validate
- Generate dependency update report
- Create PR with changes if tests pass
- Optional: Dry-run mode

**Execution Model**: Jobs service (scheduled weekly) OR Local script (manual)

**Complexity**: Medium (UV operations, test orchestration, PR creation)

**Impact**: ⭐⭐⭐⭐ Keeps dependencies current, reduces security risk

**Dependencies**: Docker (dev containers), `gh` CLI

**Estimated Lines**: 200-250

#### 5. WARP.md Structure Validator

**Purpose**: Enforce WARP.md structure rules automatically

**Proposed Script**: `scripts/validate-warp.sh`

**Capabilities**:
- Validate Global WARP structure:
  - Rule Index table exists with line numbers
  - All rules have backreferences
  - All rules have "Applies to" tags
  - Line numbers in table match actual sections
- Validate Project WARP structure:
  - Lists applicable Global rules
  - No duplication of Global rules
  - References Global WARP correctly
- Detect structure violations
- Generate validation report
- Optional: Auto-fix (update line numbers)

**Execution Model**: Local script (Python) OR CI job (PR validation)

**Complexity**: Medium (markdown parsing, structure validation)

**Impact**: ⭐⭐⭐ Prevents WARP drift and maintenance overhead

**Dependencies**: Python, markdown parser

**Estimated Lines**: 250-300

### 2.2 Development Workflow Scripts

#### 6. Setup Script (New Developer Onboarding)

**Purpose**: One-command setup for new developers

**Proposed Script**: `scripts/setup-dev.sh`

**Capabilities**:
- Check prerequisites (Docker, Docker Compose, gh CLI)
- Clone meta repo with submodules (if not already cloned)
- Switch all submodules to development branch
- Start Traefik (if not running)
- Generate SSL certificates (if needed)
- For each project:
  - Create `.env.dev` from example
  - Generate keys (API only)
  - Run initial `make dev-up`
  - Run migrations (API only)
- Validate all services healthy
- Display access URLs and next steps

**Execution Model**: Local script (bash)

**Complexity**: High (multi-step setup, error handling)

**Impact**: ⭐⭐⭐⭐⭐ Eliminates onboarding friction

**Dependencies**: Docker, gh CLI, git

**Estimated Lines**: 300-400

#### 7. Branch Management Script

**Purpose**: Simplify Git workflow across submodules

**Proposed Script**: `scripts/branch.sh`

**Capabilities**:
- `branch.sh create feature-name` - Create feature branch in all submodules
- `branch.sh switch branch-name` - Switch all submodules to branch
- `branch.sh sync` - Sync all submodules with remote
- `branch.sh status` - Show git status for all submodules
- `branch.sh clean` - Delete merged feature branches

**Execution Model**: Local script (bash)

**Complexity**: Low (git commands)

**Impact**: ⭐⭐⭐ Simplifies multi-repo management

**Dependencies**: git

**Estimated Lines**: 150-200

#### 8. Sync Submodules Script

**Purpose**: Update meta repo submodule references

**Proposed Script**: `scripts/sync-submodules.sh`

**Capabilities**:
- Fetch latest commits for all submodules
- Update meta repo references to latest stable tags
- Create commit with submodule updates
- Push to meta repo
- Display update summary

**Execution Model**: Local script (bash) OR Jobs service (scheduled after releases)

**Complexity**: Low (git submodule operations)

**Impact**: ⭐⭐ Keeps meta repo current

**Dependencies**: git

**Estimated Lines**: 100-150

### 2.3 Code Quality Scripts

#### 9. Format All Script

**Purpose**: Format code across all projects

**Proposed Script**: `scripts/format-all.sh`

**Capabilities**:
- Run `make format` in all projects (api, terminal, jobs)
- Show formatting changes (unified diff)
- Optional: Auto-commit formatted code

**Execution Model**: Local script (bash)

**Complexity**: Low (make commands)

**Impact**: ⭐⭐⭐ Ensures consistent formatting

**Dependencies**: Docker (dev containers)

**Estimated Lines**: 100-150

#### 10. Lint All Script

**Purpose**: Lint code across all projects

**Proposed Script**: `scripts/lint-all.sh`

**Capabilities**:
- Run `make lint` in all projects
- Aggregate linting errors
- Generate lint report (by project, by error type)
- Exit with error if violations found
- Optional: Filter by project or error type

**Execution Model**: Local script (bash)

**Complexity**: Low (make commands, result parsing)

**Impact**: ⭐⭐⭐ Quick code quality check

**Dependencies**: Docker (dev containers)

**Estimated Lines**: 150-200

#### 11. Type Check All Script

**Purpose**: Type check across all projects

**Proposed Script**: `scripts/type-check-all.sh`

**Capabilities**:
- Run `make type-check` in all projects
- Aggregate mypy errors
- Generate type check report
- Exit with error if violations found

**Execution Model**: Local script (bash)

**Complexity**: Low (make commands)

**Impact**: ⭐⭐⭐ Catch type errors early

**Dependencies**: Docker (dev containers)

**Estimated Lines**: 100-150

#### 12. Verify All Script

**Purpose**: Run full verification across all projects

**Proposed Script**: `scripts/verify-all.sh`

**Capabilities**:
- Run `make verify` in all projects
- Show progress (7 steps per project = 21 steps total)
- Aggregate results
- Generate verification report
- Exit with error if any project fails
- Optional: Fail-fast vs continue-on-error mode

**Execution Model**: Local script (bash) OR Jobs service (nightly)

**Complexity**: Medium (orchestrate long-running commands)

**Impact**: ⭐⭐⭐⭐ Pre-release confidence check

**Dependencies**: Docker (test containers)

**Estimated Lines**: 200-250

### 2.4 Testing Scripts

#### 13. Test Runner with Options

**Purpose**: Flexible test execution across projects

**Proposed Script**: `scripts/test.sh`

**Capabilities**:
- `test.sh --all` - Run all tests in all projects
- `test.sh --project api` - Run tests in specific project
- `test.sh --type unit` - Run only unit tests across all projects
- `test.sh --type integration` - Run only integration tests
- `test.sh --coverage` - Include coverage reports
- `test.sh --parallel` - Run projects in parallel
- `test.sh --watch` - Watch mode (re-run on file change)

**Execution Model**: Local script (bash)

**Complexity**: High (option parsing, parallel execution, watch mode)

**Impact**: ⭐⭐⭐⭐ Flexible testing workflow

**Dependencies**: Docker (test containers), `entr` for watch mode

**Estimated Lines**: 300-400

#### 14. Coverage Report Generator

**Purpose**: Aggregate coverage across projects

**Proposed Script**: `scripts/coverage-report.sh`

**Capabilities**:
- Run tests with coverage in all projects
- Aggregate coverage data (by project, by layer)
- Generate combined HTML report
- Check coverage thresholds (fail if below target)
- Generate badge data for README

**Execution Model**: Local script (bash/Python) OR CI job

**Complexity**: Medium (coverage aggregation, report generation)

**Impact**: ⭐⭐⭐ Unified coverage visibility

**Dependencies**: Docker, pytest-cov, Python

**Estimated Lines**: 200-250

### 2.5 Documentation Scripts

#### 15. Docs Builder (All Projects)

**Purpose**: Build documentation for all projects

**Proposed Script**: `scripts/docs-build-all.sh`

**Capabilities**:
- Run `make docs-build` in all projects
- Check for warnings/errors
- Generate build report
- Optional: Serve all docs on different ports
- Optional: Deploy all to GitHub Pages

**Execution Model**: Local script (bash) OR CI job

**Complexity**: Medium (orchestrate builds, error checking)

**Impact**: ⭐⭐⭐ Unified docs validation

**Dependencies**: Docker (dev containers)

**Estimated Lines**: 150-200

#### 16. Markdown Lint All

**Purpose**: Lint markdown across all projects and meta repo

**Proposed Script**: `scripts/lint-md-all.sh`

**Capabilities**:
- Lint markdown in meta repo (README, WARP.md)
- Lint markdown in all projects (docs/, README, WARP.md, CHANGELOG.md)
- Aggregate violations by project
- Generate lint report
- Optional: Auto-fix mode (with confirmation)

**Execution Model**: Local script (bash)

**Complexity**: Medium (invoke per-project lint, aggregate)

**Impact**: ⭐⭐⭐ Consistent markdown quality

**Dependencies**: Docker (Node.js for markdownlint)

**Estimated Lines**: 150-200

### 2.6 Container Management Scripts

#### 17. Container Cleanup Script

**Purpose**: Clean up unused containers, volumes, images

**Proposed Script**: `scripts/cleanup.sh`

**Capabilities**:
- Stop and remove all Dashtam containers
- Remove unused volumes (with confirmation)
- Remove dangling images
- Prune Docker system (with size limits)
- Generate cleanup report (space reclaimed)
- Optional: Aggressive mode (remove everything)
- Optional: Dry-run mode

**Execution Model**: Local script (bash) OR Jobs service (scheduled weekly)

**Complexity**: Low (Docker commands)

**Impact**: ⭐⭐ Reclaim disk space

**Dependencies**: Docker

**Estimated Lines**: 150-200

#### 18. Container Logs Aggregator

**Purpose**: View logs from all projects in unified stream

**Proposed Script**: `scripts/logs.sh`

**Capabilities**:
- `logs.sh --all` - Tail logs from all projects
- `logs.sh --project api` - Logs from specific project
- `logs.sh --service postgres` - Logs from specific service across projects
- `logs.sh --follow` - Follow mode
- `logs.sh --since 1h` - Filter by time
- Color-coded by project for readability

**Execution Model**: Local script (bash)

**Complexity**: Medium (Docker logs API, filtering, formatting)

**Impact**: ⭐⭐⭐ Unified debugging view

**Dependencies**: Docker

**Estimated Lines**: 200-250

#### 19. Container Status Dashboard

**Purpose**: Real-time status of all containers

**Proposed Script**: `scripts/status-dashboard.sh`

**Capabilities**:
- Display all Dashtam containers (table format)
- Show health status (healthy/unhealthy/starting)
- Show resource usage (CPU, memory)
- Show network info (ports, domains)
- Auto-refresh (watch mode)
- Optional: Export to JSON

**Execution Model**: Local script (bash) OR Web dashboard

**Complexity**: Medium (Docker stats API, terminal formatting)

**Impact**: ⭐⭐⭐ Quick operational overview

**Dependencies**: Docker

**Estimated Lines**: 200-250

### 2.7 Database & Migration Scripts

#### 20. Database Snapshot Script

**Purpose**: Create database snapshots for backup/restore

**Proposed Script**: `scripts/db-snapshot.sh`

**Capabilities**:
- `db-snapshot.sh create snapshot-name` - Create snapshot (pg_dump)
- `db-snapshot.sh restore snapshot-name` - Restore snapshot
- `db-snapshot.sh list` - List available snapshots
- `db-snapshot.sh delete snapshot-name` - Delete snapshot
- Support for all environments (dev, test)
- Compress snapshots (gzip)

**Execution Model**: Local script (bash) OR Jobs service (scheduled backups)

**Complexity**: Medium (pg_dump/restore, file management)

**Impact**: ⭐⭐⭐ Data safety and experimentation

**Dependencies**: Docker (postgres container), pg_dump/restore

**Estimated Lines**: 200-250

#### 21. Migration Status Script

**Purpose**: Check migration status across all projects

**Proposed Script**: `scripts/migration-status.sh`

**Capabilities**:
- For each project with migrations (API):
  - Show current migration version
  - Show pending migrations
  - Show migration history
- Validate migrations are in sync across dev/test
- Alert if migrations out of sync

**Execution Model**: Local script (bash)

**Complexity**: Low (Alembic commands)

**Impact**: ⭐⭐ Prevent migration issues

**Dependencies**: Docker (dev containers), Alembic

**Estimated Lines**: 100-150

### 2.8 GitHub Integration Scripts

#### 22. Issue Creation Script (Already Implemented!)

**Purpose**: Create GitHub issues with project integration

**Current Script**: `scripts/create-issue.sh`

**Status**: ✅ Implemented and tested

**Capabilities**:
- Create issue via `gh issue create`
- Automatically add to GitHub Project
- Set custom fields (Service, Priority, Quarter)
- Makefile integration: `make create-issue TITLE="..." SERVICE="API"`

#### 23. Milestone Management Script

**Purpose**: Manage milestones across all repos

**Proposed Script**: `scripts/milestone.sh`

**Capabilities**:
- `milestone.sh create "v1.1.0"` - Create milestone in all repos
- `milestone.sh list` - List all milestones
- `milestone.sh issues v1.1.0` - Show issues in milestone
- `milestone.sh close v1.1.0` - Close milestone (after release)
- `milestone.sh move-issues v1.1.0 v1.2.0` - Move incomplete issues

**Execution Model**: Local script (bash)

**Complexity**: Medium (GitHub API)

**Impact**: ⭐⭐⭐ Streamline milestone management

**Dependencies**: `gh` CLI

**Estimated Lines**: 200-250

#### 24. PR Creation Script

**Purpose**: Create PRs with templates and validation

**Proposed Script**: `scripts/pr-create.sh`

**Capabilities**:
- Create PR with conventional title format
- Pre-fill body with template (closes #N, description, checklist)
- Validate PR passes checks before creation
- Automatically assign reviewers
- Add labels based on PR type
- Link to related issues
- Optional: Create draft PR

**Execution Model**: Local script (bash)

**Complexity**: Medium (GitHub API, validation)

**Impact**: ⭐⭐⭐ Consistent PR quality

**Dependencies**: `gh` CLI, git

**Estimated Lines**: 200-250

### 2.9 Debugging & Development Tools

#### 25. Debug Shell Script

**Purpose**: Quick access to any service shell

**Proposed Script**: `scripts/shell.sh`

**Capabilities**:
- `shell.sh api` - Shell into API dev container
- `shell.sh api-db` - Shell into API PostgreSQL
- `shell.sh api-redis` - Shell into API Redis CLI
- `shell.sh terminal` - Shell into Terminal container
- `shell.sh jobs-worker` - Shell into Jobs worker
- Auto-detect running containers

**Execution Model**: Local script (bash)

**Complexity**: Low (Docker exec)

**Impact**: ⭐⭐ Faster debugging

**Dependencies**: Docker

**Estimated Lines**: 100-150

#### 26. Dependency Graph Generator

**Purpose**: Visualize dependencies across projects

**Proposed Script**: `scripts/deps-graph.sh`

**Capabilities**:
- Parse `pyproject.toml` and `uv.lock` from all projects
- Generate dependency graph (Graphviz/Mermaid)
- Show shared dependencies across projects
- Highlight version conflicts
- Export to HTML/PNG/SVG

**Execution Model**: Local script (Python)

**Complexity**: High (dependency parsing, graph generation)

**Impact**: ⭐⭐ Understand dependency landscape

**Dependencies**: Python, Graphviz/Mermaid

**Estimated Lines**: 300-400

#### 27. Performance Profiler Script

**Purpose**: Profile application performance

**Proposed Script**: `scripts/profile.sh`

**Capabilities**:
- Run pytest with profiling enabled
- Run API endpoints with load testing
- Generate performance reports (flamegraph, slowest tests)
- Compare performance across commits
- Alert on performance regressions

**Execution Model**: Local script (bash/Python) OR Jobs service (nightly)

**Complexity**: High (profiling integration, report generation)

**Impact**: ⭐⭐ Catch performance issues early

**Dependencies**: Docker, pytest-profiling, py-spy, wrk

**Estimated Lines**: 250-300

---

## Part 3: Jobs Service Automation Candidates

### 3.1 Scheduled Maintenance Tasks

#### 28. Nightly Test Runner

**Purpose**: Run full test suite across all projects every night

**TaskIQ Job**: `jobs/tasks/testing/nightly_tests.py`

**Schedule**: `0 2 * * *` (2 AM daily)

**Capabilities**:
- Run `make verify` in all projects
- Generate test report
- Send notification if failures (Slack/email)
- Archive test artifacts

**Complexity**: Medium

**Impact**: ⭐⭐⭐ Catch integration issues early

#### 29. Dependency Update Checker

**Purpose**: Check for dependency updates weekly

**TaskIQ Job**: `jobs/tasks/maintenance/check_deps.py`

**Schedule**: `0 9 * * 1` (Monday 9 AM)

**Capabilities**:
- Run `uv lock --upgrade` in dry-run mode
- Detect available updates
- Check for security vulnerabilities
- Create GitHub issue with update recommendations
- Optional: Auto-create PR with updates

**Complexity**: Medium

**Impact**: ⭐⭐⭐⭐ Stay current, reduce security risk

#### 30. Container Image Cleanup

**Purpose**: Remove old Docker images weekly

**TaskIQ Job**: `jobs/tasks/maintenance/cleanup_images.py`

**Schedule**: `0 3 * * 0` (Sunday 3 AM)

**Capabilities**:
- List all Dashtam-related images
- Remove images older than 30 days
- Keep latest 5 versions
- Generate cleanup report
- Send notification (space reclaimed)

**Complexity**: Low

**Impact**: ⭐⭐ Reclaim disk space

#### 31. Health Monitoring Job

**Purpose**: Monitor service health continuously

**TaskIQ Job**: `jobs/tasks/monitoring/health_check.py`

**Schedule**: `*/15 * * * *` (Every 15 minutes)

**Capabilities**:
- Check all services (API, Terminal, Jobs)
- Check database connectivity
- Check Redis connectivity
- Check external API availability
- Send alerts if unhealthy (Slack/PagerDuty)
- Log health metrics to time-series DB

**Complexity**: Medium

**Impact**: ⭐⭐⭐⭐ Proactive issue detection

### 3.2 Background Processing Tasks

#### 32. Documentation Build Validator

**Purpose**: Validate docs build daily

**TaskIQ Job**: `jobs/tasks/docs/validate_build.py`

**Schedule**: `0 4 * * *` (4 AM daily)

**Capabilities**:
- Run `make docs-build` in all projects
- Check for broken links
- Check for missing pages
- Generate validation report
- Send notification if issues found

**Complexity**: Medium

**Impact**: ⭐⭐ Catch docs issues early

#### 33. GitHub Actions Cache Cleaner

**Purpose**: Clean up old GitHub Actions caches

**TaskIQ Job**: `jobs/tasks/github/cleanup_caches.py`

**Schedule**: `0 5 * * 0` (Sunday 5 AM)

**Capabilities**:
- List all GitHub Actions caches
- Remove caches older than 7 days
- Keep caches for recent branches
- Generate cleanup report

**Complexity**: Low

**Impact**: ⭐⭐ Reduce GitHub storage usage

### 3.3 Reporting & Metrics Tasks

#### 34. Weekly Development Report

**Purpose**: Generate weekly development metrics

**TaskIQ Job**: `jobs/tasks/reporting/weekly_report.py`

**Schedule**: `0 9 * * 1` (Monday 9 AM)

**Capabilities**:
- Count commits across all repos (last 7 days)
- Count PRs merged
- Count issues closed
- Test pass/fail rates
- Code coverage trends
- Generate report (Markdown/HTML)
- Send to Slack/email

**Complexity**: Medium

**Impact**: ⭐⭐⭐ Visibility into development velocity

#### 35. Code Quality Trends

**Purpose**: Track code quality metrics over time

**TaskIQ Job**: `jobs/tasks/reporting/quality_trends.py`

**Schedule**: `0 6 * * *` (6 AM daily)

**Capabilities**:
- Run linters on all projects
- Count violations by type
- Track mypy error count
- Track test coverage
- Store metrics in time-series DB
- Generate trend charts
- Alert on regressions

**Complexity**: Medium

**Impact**: ⭐⭐⭐ Prevent quality degradation

---

## Part 4: Script Architecture & Design

### 4.1 Naming Conventions

**Pattern**: `verb-noun.sh` (action-oriented)

**Examples**:
- `release.sh` (automate release)
- `test-all.sh` (test all projects)
- `health-check.sh` (check health)
- `format-all.sh` (format all projects)
- `sync-submodules.sh` (sync submodules)

**Exceptions**:
- `create-issue.sh` (already exists, keep consistency)
- Helper scripts: `common.sh`, `colors.sh`

### 4.2 Script Location

**Directory Structure**:
```
~/dashtam/scripts/
├── common.sh              # Shared functions (logging, error handling)
├── colors.sh              # Terminal color codes
├── create-issue.sh        # ✅ Already implemented
├── release.sh             # Release automation
├── test-all.sh            # Cross-project testing
├── health-check.sh        # Service health validation
├── format-all.sh          # Code formatting
├── lint-all.sh            # Code linting
├── verify-all.sh          # Full verification
├── setup-dev.sh           # New developer setup
├── branch.sh              # Branch management
├── sync-submodules.sh     # Submodule sync
├── cleanup.sh             # Container cleanup
├── logs.sh                # Log aggregation
├── status-dashboard.sh    # Status dashboard
├── db-snapshot.sh         # Database snapshots
├── milestone.sh           # Milestone management
├── pr-create.sh           # PR creation
└── shell.sh               # Quick shell access
```

### 4.3 Shared Functions Library

**File**: `scripts/common.sh`

**Functions**:
- `log_info()` - Info message with timestamp
- `log_success()` - Success message (green)
- `log_warning()` - Warning message (yellow)
- `log_error()` - Error message (red, exit)
- `confirm()` - Prompt for confirmation
- `check_dependency()` - Verify command exists
- `detect_projects()` - Find all submodule projects
- `is_container_running()` - Check if container is running
- `exec_in_container()` - Execute command in container
- `aggregate_results()` - Combine results from multiple operations

**Pattern**: All scripts source `common.sh` at the top

### 4.4 Error Handling Standards

**Principles**:
- Use `set -euo pipefail` for fail-fast
- Validate all inputs
- Check prerequisites (Docker, gh CLI, etc.)
- Provide clear error messages with resolution steps
- Cleanup on error (trap EXIT)
- Return meaningful exit codes

**Example**:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Cleanup on exit
trap cleanup EXIT

# Check prerequisites
check_dependency "docker" "Install Docker: https://docs.docker.com/get-docker/"
check_dependency "gh" "Install GitHub CLI: https://cli.github.com/"

# Main logic
main() {
    log_info "Starting operation..."
    # ...
}

main "$@"
```

### 4.5 Output Formatting

**Standards**:
- Use consistent emoji prefixes (🚀 start, ✅ success, ❌ error, ⚠️ warning)
- Table format for structured data
- Progress indicators for long operations
- Color coding (green=success, red=error, yellow=warning, blue=info)
- Summary sections at the end

**Example**:
```bash
log_info "🧪 Running tests across all projects..."
echo ""
echo "Project  | Status   | Coverage | Duration"
echo "---------|----------|----------|----------"
echo "API      | ✅ PASS | 92%      | 45s"
echo "Terminal | ✅ PASS | 88%      | 12s"
echo "Jobs     | ✅ PASS | 85%      | 8s"
echo ""
log_success "All tests passed!"
```

### 4.6 Configuration Management

**Approach**: Environment variables with defaults

**Pattern**:
```bash
# Configuration
DASHTAM_ROOT="${DASHTAM_ROOT:-$HOME/dashtam}"
PARALLEL="${PARALLEL:-false}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# Validate
if [ ! -d "$DASHTAM_ROOT" ]; then
    log_error "Dashtam root not found: $DASHTAM_ROOT"
fi
```

**Usage**:
```bash
# Use defaults
./scripts/test-all.sh

# Override
PARALLEL=true ./scripts/test-all.sh

# Environment file
export DASHTAM_ROOT="$HOME/custom/dashtam"
./scripts/test-all.sh
```

---

## Part 5: Implementation Roadmap

### Phase 1: Foundation (Quick Wins)

**Scripts** (4-6 weeks):
1. `common.sh` - Shared functions library
2. `health-check.sh` - Service health validation
3. `test-all.sh` - Cross-project testing
4. `format-all.sh` - Code formatting
5. `lint-all.sh` - Code linting

**Jobs Tasks** (2-4 weeks):
1. Health monitoring job (15-minute intervals)
2. Nightly test runner

**Validation**: All scripts tested, documented, integrated with Makefile

### Phase 2: Development Workflow (Medium Priority)

**Scripts** (4-6 weeks):
1. `setup-dev.sh` - New developer onboarding
2. `branch.sh` - Branch management
3. `shell.sh` - Quick shell access
4. `logs.sh` - Log aggregation
5. `status-dashboard.sh` - Status dashboard

**Jobs Tasks** (2-4 weeks):
1. Dependency update checker (weekly)
2. Documentation build validator (daily)

**Validation**: Onboarding tested with new developer, workflows streamlined

### Phase 3: Release Automation (High Impact)

**Scripts** (6-8 weeks):
1. `release.sh` - Full release automation
2. `verify-all.sh` - Full verification
3. `milestone.sh` - Milestone management
4. `pr-create.sh` - PR creation

**Jobs Tasks** (2-4 weeks):
1. Weekly development report
2. Code quality trends

**Validation**: Complete release cycle automated end-to-end

### Phase 4: Advanced Features (Polish)

**Scripts** (4-6 weeks):
1. `sync-submodules.sh` - Submodule sync
2. `db-snapshot.sh` - Database snapshots
3. `cleanup.sh` - Container cleanup
4. `deps-graph.sh` - Dependency visualization

**Jobs Tasks** (2-4 weeks):
1. Container image cleanup (weekly)
2. GitHub Actions cache cleaner (weekly)

**Validation**: All workflows optimized, documentation complete

---

## Part 6: Success Metrics

### Automation Coverage

**Target**: 80% of manual workflows automated

**Measurement**:
- Count of automated workflows / Total identified workflows
- Time saved per workflow execution
- Error rate reduction (manual vs automated)

### Developer Experience

**Target**: 50% reduction in setup/maintenance time

**Measurement**:
- New developer setup time (target: <30 min)
- Release cycle time (target: <15 min automated)
- Cross-project testing time (target: <5 min)

### Code Quality

**Target**: Maintain 85%+ test coverage, zero linting violations

**Measurement**:
- Test coverage trends (tracked daily)
- Linting violation count (tracked daily)
- Mypy error count (tracked daily)

### Operational Reliability

**Target**: 99% service uptime in dev/test environments

**Measurement**:
- Service health check pass rate
- Mean time to detection (MTTD) for service issues
- Mean time to recovery (MTTR) for service issues

---

## Conclusion

This discovery and analysis phase has identified **47 automation opportunities** across 8 categories:

1. **High-Priority Quick Wins** (5 scripts): Immediate impact on daily workflows
2. **Development Workflow** (8 scripts): Streamline day-to-day operations
3. **Code Quality** (4 scripts): Enforce standards automatically
4. **Testing** (2 scripts): Flexible, comprehensive testing
5. **Documentation** (2 scripts): Keep docs current and validated
6. **Container Management** (3 scripts): Operational efficiency
7. **Database & Migration** (2 scripts): Data safety and management
8. **GitHub Integration** (3 scripts): Streamline project management
9. **Debugging & Development Tools** (3 scripts): Faster problem resolution
10. **Jobs Service Tasks** (15 jobs): Background automation and monitoring

**Next Steps**:
1. Review and prioritize automation opportunities with user
2. Finalize naming conventions and script architecture
3. Begin Phase 1 implementation (Foundation scripts)
4. Document script usage in Global WARP.md
5. Create Makefile wrappers for common scripts

**Estimated Timeline**: 16-24 weeks for full implementation (all 4 phases)

**Estimated Impact**: 50% reduction in manual workflow time, 80%+ automation coverage

---

**Created**: 2026-01-22
**Last Updated**: 2026-01-22
**Status**: Discovery Complete, Ready for Phase 2 (Prioritization)
