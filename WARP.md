# Dashtam Suite — Global Rules and Context

**Purpose**: Shared standards for all Dashtam projects. Project-specific rules in each project's WARP.md.

---

## ⚠️ For AI Agents: WARP.md Structure Rules

**CRITICAL**: When updating WARP.md files, you MUST preserve this structure:

1. **Global WARP** (`~/dashtam/WARP.md`):
   - Contains Rule Index table with line numbers
   - Contains full definitions of all universal rules
   - Each rule section has: **Index** backreference + **Applies to** tag
   - NO project-specific content

2. **Project WARPs** (api/WARP.md, terminal/WARP.md):
   - Lists applicable Global rules (by number)
   - References Global WARP for definitions ("See `~/dashtam/WARP.md` Rule X")
   - Contains ONLY project-specific rules
   - NO duplication of Global rules

3. **When adding a new rule**:
   - Add to Global WARP Rule Index table (with line number)
   - Add rule section with backreference: `**Index**: See Rule Index (Line X)`
   - Add applicability tag: `**Applies to**: [projects]`
   - Update project WARPs to reference it

4. **Never**:
   - Duplicate universal rules in project WARPs
   - Add project-specific content to Global WARP
   - Hardcode version numbers (use "latest stable" or reference pyproject.toml)
   - Reference external docs (~/references/* - being sunset)

**This structure ensures single source of truth and prevents content drift.**

---

## Rule Index

**Instructions**: When adding a new rule section, update this table AND add backreference in section header.

| # | Rule Section | Line | API | Terminal | Jobs | CLI | Web | Notes |
|---|--------------|------|-----|----------|------|-----|-----|-------|
| 1 | Repository Structure | 50 | ✅ | ✅ | ✅ | ✅ | ✅ | Meta repo with submodules |
| 2 | Development Philosophy | 160 | ✅ | ✅ | ✅ | ✅ | ✅ | Universal principles |
| 3 | Modern Python Patterns | 180 | ✅ | ✅ | ✅ | ✅ | ✅ | Protocol, types, Result |
| 4 | Docker Containerization | 320 | ✅ | ✅ | ✅ | ✅ | ✅ | Common patterns, commands |
| 5 | Git Workflow | 460 | ✅ | ✅ | ✅ | ✅ | ✅ | Branches, commits, releases |
| 6 | Code Quality Standards | 600 | ✅ | ✅ | ✅ | ✅ | ✅ | Ruff, mypy, docstrings |
| 7 | Testing Philosophy | 700 | ✅ | ✅ | ✅ | ✅ | ✅ | Coverage, test types |
| 8 | Environment Configuration | 800 | ✅ | ✅ | ✅ | ✅ | ✅ | .env files, setup |
| 9 | Documentation Standards | 880 | ✅ | ✅ | ✅ | ✅ | ✅ | Markdown lint, MkDocs |
| 10 | AI Agent Instructions | 980 | ✅ | ✅ | ✅ | ✅ | ✅ | Mandatory process, TODOs |
| 11 | GitHub Project | 1100 | ✅ | ✅ | ✅ | ✅ | ✅ | Unified platform tracking |
| 12 | GitHub Issues Workflow | 1240 | ✅ | ✅ | ✅ | ✅ | ✅ | Issue lifecycle, templates |

**Legend**: ✅ = Fully applies, ⚠️ = Partially applies (see notes), - = Not applicable

---

## 1. Repository Structure
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

Dashtam uses a **meta repository** with **Git submodules** for multi-project coordination while keeping each project independent.

### Repositories

| Repository | Description | Status |
|------------|-------------|--------|
| `dashtam` | Meta repository | Active |
| `dashtam-api` | Financial data aggregation API (FastAPI) | Active |
| `dashtam-terminal` | Bloomberg-style TUI (Textual) | Active |
| `dashtam-jobs` | Background job service | Foundation |
| `dashtam-web` | Web frontend | Planned |
| `dashtam-cli` | Standalone CLI tool | Planned |

### Local Structure

```
~/dashtam/                    # Meta repo (dashtam)
├── .git/
├── .gitmodules               # Submodule references
├── README.md
├── WARP.md                   # This file (shared rules)
├── api/                      # Submodule → dashtam-api
│   ├── .git/
│   └── WARP.md               # API-specific rules
├── terminal/                 # Submodule → dashtam-terminal
│   ├── .git/
│   └── WARP.md               # Terminal-specific rules
├── jobs/                     # Submodule → dashtam-jobs
│   └── WARP.md               # Jobs-specific rules
├── web/                      # Future submodule
└── cli/                      # Future submodule
```

### New Machine Setup

Clone the entire suite with one command:

```bash
git clone --recurse-submodules git@github.com:faiyaz7283/dashtam.git ~/dashtam
```

If already cloned without submodules:

```bash
cd ~/dashtam
git submodule update --init --recursive
```

### Submodule Workflow

**Daily development** — Work in submodules as normal repos:

```bash
cd ~/dashtam/api
git checkout development
# ... make changes ...
git add . && git commit -m "feat: ..."
git push origin development
```

**Switching branches** — After cloning, switch to your working branch:

```bash
cd ~/dashtam/api
git fetch --all
git checkout development          # Or any feature branch
```

**Updating meta repo** — After releases, update the tracked commit:

```bash
cd ~/dashtam
git add api                       # Stage submodule update
git commit -m "chore: update api to latest stable"
git push
```

**Pulling updates on another machine:**

```bash
cd ~/dashtam
git pull
git submodule update --init       # Updates to tracked commits
cd api && git checkout development # Switch to working branch
```

### When to Update Meta Repo

| Approach | When | Use case |
|----------|------|----------|
| Per-release | After version tags | Recommended — stable references |
| Per-milestone | After feature completion | Alternative — milestone tracking |
| Per-commit | Every submodule push | Not recommended — too noisy |

**Recommended**: Update meta repo after releases so it always points to stable, tagged versions.

---

## 2. Development Philosophy
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

**Core Principles** (apply to ALL projects):

- **Clean Architecture** — Separation of concerns, dependency inversion
- **Type Safety** — Type hints everywhere, strict mypy
- **Protocol-Based** — Structural typing with `Protocol` (NOT ABC)
- **Result Types** — Explicit error handling, no silent failures
- **Documentation-First** — Architecture decisions documented before coding
- **Test-Driven** — High coverage, meaningful tests
- **Latest Stable** — Always prefer latest stable versions of all technology

---

## 3. Modern Python Patterns
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

**CRITICAL**: All projects use Python 3.14+ features consistently. Always prefer latest stable Python version.

### Protocol over ABC (Mandatory)

```python
# ✅ CORRECT: Use Protocol
from typing import Protocol

class CacheProtocol(Protocol):
    async def get(self, key: str) -> str | None: ...
    async def set(self, key: str, value: str, ttl: int) -> None: ...

# Implementation doesn't inherit
class RedisCache:  # No inheritance!
    async def get(self, key: str) -> str | None:
        return await self.redis.get(key)

# ❌ WRONG: Don't use ABC
from abc import ABC, abstractmethod
class CacheBackend(ABC):  # Don't do this
    pass
```

### Type Hints Everywhere

```python
# ✅ CORRECT: Modern type hints
def process(user_id: UUID, data: dict[str, Any]) -> User | None:
    ...

# ❌ WRONG: Old-style
from typing import Optional, Dict
def process(user_id: UUID, data: Dict[str, Any]) -> Optional[User]:
    ...
```

**Rules**:

- All function parameters have type hints
- All return types specified
- Use `X | None` (NOT `Optional[X]`)
- Use `list`, `dict`, `set` (NOT `List`, `Dict`, `Set`)

### Result Types (Railway-Oriented Programming)

```python
from core.result import Result, Success, Failure

def create_user(email: str) -> Result[User, ValidationError]:
    if not is_valid_email(email):
        return Failure(error=ValidationError("Invalid email"))
    return Success(value=user)

# Handle with isinstance (kw_only dataclasses)
if isinstance(result, Failure):
    return Failure(error=result.error)
value = result.value  # Type narrowed to Success
```

---

## 4. Docker Containerization
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

**CRITICAL**: ALL development happens in Docker containers. No local Python environments.

### Common Patterns

```yaml
# Multi-stage Dockerfile with UV (latest stable)
FROM ghcr.io/astral-sh/uv:latest-python3.14-trixie-slim AS base
WORKDIR /app

# Anonymous volume for .venv (preserves across rebuilds)
volumes:
  - .:/app
  - /app/.venv  # Anonymous volume
```

### Makefile Commands (Consistent Across Projects)

All projects use `dev-*` prefix for development commands:

```bash
make dev-up        # Start development environment
make dev-down      # Stop development environment
make dev-shell     # Shell into app container
make dev-logs      # View logs
make dev-restart   # Restart environment
make dev-build     # Build containers
make dev-rebuild   # Rebuild without cache
```

### Code Quality Commands

```bash
make lint          # Run linters (ruff)
make format        # Format code (ruff)
make type-check    # Type check (mypy)
make test          # Run tests
make verify        # Full verification (format, lint, type-check, test)
```

---

## 5. Git Workflow
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

### Branch Structure

- `main` — Production-ready code (protected)
- `development` — Integration branch (protected)
- `feature/*` — New features
- `fix/*` — Bug fixes

### Conventional Commits

**Format**: `<type>(<scope>): <subject> (#issue)`

```bash
feat(auth): add JWT authentication (#42)
fix(api): handle token expiration correctly (#43)
docs(readme): add installation instructions
test(integration): add user registration tests (#44)
chore(deps): update httpx to latest stable
```

**Co-author** (required for AI-assisted commits):

```
Co-Authored-By: Warp <agent@warp.dev>
```

**Issue References**: Include `(#N)` for feature/fix commits. See Rule 11 for full GitHub Issues workflow.

### Branch Protection

Both `main` and `development` are protected:

- ✅ Required: CI checks passing
- ✅ Required: Conversations resolved
- ❌ No direct commits (PR required)
- ❌ No force pushes

### Release Workflow

**Release Process**:

1. Verify all milestone issues are closed (or moved to next milestone)
2. Create release PR from `development` → `main`
3. After merge, tag release: `git tag -a vX.Y.Z -m "message"` and push tag
4. Create GitHub Release: `gh release create vX.Y.Z --title "..." --notes "..."`
5. Sync main back to development:

```bash
git checkout development
git pull origin development
git merge origin/main --no-edit
git push origin development
```

6. Close the milestone on GitHub (if all issues complete)

See project-specific WARP.md for detailed release checklists.

---

## 6. Code Quality Standards
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

### Ruff (Linting + Formatting)

Use latest stable Ruff configuration:

```toml
[tool.ruff]
line-length = 88
target-version = "py314"

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "C4", "UP", "ARG", "SIM", "TCH", "PTH", "RUF"]
```

### Mypy (Type Checking)

```toml
[tool.mypy]
strict = true
warn_return_any = true
warn_unused_configs = true
```

### Google-Style Docstrings

```python
def fetch_accounts(user_id: UUID) -> Result[list[Account], FetchError]:
    """Fetch all accounts for a user.

    Args:
        user_id: The user's unique identifier.

    Returns:
        Success with list of accounts, or Failure with FetchError.

    Raises:
        NetworkError: If API is unreachable.
    """
```

---

## 7. Testing Philosophy
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

**Coverage Targets**:

- Core/Domain: 95%+
- Application: 90%+
- Infrastructure: 70%+
- Presentation: 85%+
- Overall: 85%+

**Test Types**:

```
tests/
├── unit/           # Pure logic tests (mocked dependencies)
├── integration/    # Database, cache, external API tests
├── api/            # HTTP endpoint tests (if applicable)
└── e2e/            # End-to-end flow tests
```

**All tests run in Docker containers**.

---

## 8. Environment Configuration
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

### .env Files

- `.env.example` — Template (committed)
- `.env.dev` — Development (gitignored, created from example)
- `.env.ci.example` — CI template (committed)

**Rule**: Never hardcode environment variables in docker-compose. Always use `env_file:`.

### Idempotent Setup

Makefiles automatically create `.env.dev` from `.env.example` if missing:

```makefile
_ensure-env-dev:
	@if [ ! -f env/.env.dev ]; then \
		cp env/.env.example env/.env.dev; \
	fi
```

---

## 9. Documentation Standards
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

### Markdown Linting (Mandatory)

```bash
# Lint markdown file
make lint-md FILE="docs/architecture/new-doc.md"

# Lint markdown directory
make lint-md DIR="docs/"

# Must return zero violations before commit
```

**Common Violations**:

- **MD022**: Add blank line before AND after headings
- **MD032**: Add blank line before AND after lists
- **MD031**: Add blank line before AND after code blocks
- **MD040**: Add language identifier to code blocks

### MkDocs Documentation

```bash
make docs-serve   # Live preview (http://localhost:8000)
make docs-build   # Must pass with ZERO warnings
```

---

## 10. AI Agent Instructions
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

### Mandatory Process

**Phase 1: Pre-Development**:

1. Create feature branch FIRST
2. Analyze architecture placement
3. Plan testing strategy
4. Create TODO list
5. **Present plan and WAIT for approval**
6. **❌ DO NOT CODE without approval**

**Phase 2: Development**:

1. Implement following TODO list
2. Test continuously
3. Run quality checks
4. **NEVER commit without user request**

### Project-Specific Rules

Each project's WARP.md contains:

- Technology stack details
- Architecture specifics
- Project-specific patterns
- Makefile command reference

**Always read the project-specific WARP.md before starting work.**

---

## 11. GitHub Project (Unified Platform Tracking)
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

**Project URL**: https://github.com/users/faiyaz7283/projects/4

**Project Name**: Dashtam Platform Development

**Purpose**: Unified tracking for all Dashtam repositories (api, terminal, jobs, cli, web).

### Issue Lifecycle

```
OPEN → Assigned → In Progress → PR Linked → CLOSED
```

**Workflow**:

1. **Create issue** using templates (`✨ Feature Request` or `🐛 Bug Report`)
2. **Assign** yourself when starting work
3. **Add `status:in-progress`** label
4. **Create feature branch** linked to issue: `feature/issue-156-description`
5. **Reference issue** in commits: `feat(scope): description (#156)`
6. **Create PR** with `Closes #156` in description (auto-links)
7. **Merge PR** → Issue auto-closes

### Labels

| Category | Labels | Purpose |
|----------|--------|---------|
| **Type** | `enhancement`, `bug`, `documentation`, `refactor`, `chore` | What kind of work |
| **Priority** | `priority:high`, `priority:medium`, `priority:lower` | Urgency level |
| **Feature** | `sse`, `auth`, `providers`, `sync`, `ai`, `terminal` | Feature area |
| **Status** | `status:in-progress`, `status:blocked`, `status:needs-review` | Track state |
| **Scope** | `breaking-change`, `security` | Special attention |

### Milestones

Milestones group related issues toward a specific release or outcome:

- **Version releases**: Check project's latest release tag
- **Feature sets**: `SSE Implementation`, `AI Integration`

Milestones show visual progress as issues close.

### Linking Conventions

| Where | Format | Example |
|-------|--------|---------|
| **Branch** | `feature/issue-{N}-{slug}` | `feature/issue-156-sse-data-sync` |
| **Commit** | `type(scope): description (#N)` | `feat(sse): add data sync mappings (#156)` |
| **PR Title** | Same as commit | `feat(sse): Data Sync Progress (Closes #156)` |
| **PR Body** | `Closes #N` | Auto-links and auto-closes |

### Issue Dependencies

Reference related issues in the issue body:

```markdown
**Dependencies**:
- Depends on #155 (foundation)
- Blocks #157 (next feature)
- Related to #158
```

### Issue Templates

Templates are stored in `.github/ISSUE_TEMPLATE/`:

- `feature_request.yml` — New features
- `bug_report.yml` — Bug reports
- `config.yml` — Template chooser config

---

## 12. GitHub Issues Workflow
**Index**: See Rule Index (Line 15) | **Applies to**: All projects

**CRITICAL**: All feature development is tracked via GitHub Issues.

### Project Type

**Organization-Level Project** (user account: faiyaz7283)

- Tracks issues from **multiple repositories** simultaneously
- Single board for entire Dashtam platform
- Custom fields apply across all repos

### Custom Fields

**1. Service** (Single Select)
- Options: `API`, `Terminal`, `Jobs`, `CLI`, `Web`, `Platform`
- Purpose: Identify which service the issue belongs to
- Auto-assign: Based on repository (api → API, terminal → Terminal, etc.)

**2. Maturity** (Single Select)
- Options: `Foundation`, `Active`, `Maintenance`, `Planning`
- Purpose: Track project lifecycle stage

**3. Contributor** (Single Select)
- Options: `Human`, `AI-Agent`, `Warp Agent`, `Collaborative`
- Purpose: Identify who worked on the issue

**4. Priority** (Single Select)
- Options: `P0 - Critical`, `P1 - High`, `P2 - Medium`, `P3 - Low`
- Purpose: Prioritize work

**5. Quarter** (Single Select)
- Options: Current and upcoming quarters, `Backlog`
- Purpose: Roadmap planning

### Status Workflow

**Status Options**:

| Status | Description | Use |
|--------|-------------|-----|
| **Backlog** | Not yet prioritized or scheduled | Ideas, future enhancements, awaiting triage |
| **Todo** | Ready to be worked on | Approved and prioritized, ready for assignment |
| **In Progress** | Currently being worked on | Actively being developed |
| **Review** | Under review or testing | PR submitted, awaiting code review, QA testing |
| **Done** | Completed and merged | Issue closed, changes deployed or merged |

**Typical Flow**:
```
Backlog → Todo → In Progress → Review → Done
(someday)  (ready)  (doing)     (checking)  (shipped)
```

### Issue Management in Project

**When creating new issues**:
1. Issue auto-appears in project when created in tracked repos
2. Set **Service** field based on repository
3. Set **Priority** based on urgency (default: P2 - Medium)
4. Set **Quarter** (current quarter for active work, Backlog for future)
5. Leave Status as **Backlog** until ready to prioritize

**When starting work**:
1. Move issue to **Todo** (if not already)
2. Assign yourself
3. Create feature branch: `feature/issue-N-description`
4. Move to **In Progress**
5. Reference in commits: `type(scope): description (#N)`

**When submitting PR**:
1. Link PR to issue (use `Closes #N` in PR description)
2. Move issue to **Review**
3. Wait for CI checks and code review

**When PR merged**:
1. Issue auto-moves to **Done** (if `Closes #N` used)
2. Close milestone if all issues complete

### Recommended Views

**Board View** (default):
- Group by: Status
- Sort by: Priority
- Filter: Show all states

**Table View**:
- Columns: Title, Service, Maturity, Priority, Status, Assignees, Labels
- Sort by: Updated (newest first)

**Roadmap View**:
- Group by: Quarter
- Timeline with milestones

**Service-Specific Views**:
- Create filtered views for each service (API, Terminal, Jobs)

### Project Management Commands

```bash
# View project in browser
gh project view 4 --owner faiyaz7283 --web

# List items
gh project item-list 4 --owner faiyaz7283 --limit 50

# Add item to project
gh project item-add 4 --owner faiyaz7283 --url <issue-url>

# List fields
gh project field-list 4 --owner faiyaz7283
```

---

**Last Updated**: 2026-01-21
