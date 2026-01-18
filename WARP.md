# Dashtam Suite — Global Rules and Context

**Purpose**: Shared standards for all Dashtam projects. Each project has its own WARP.md for project-specific rules.

**Projects**:

- `api/` — Financial data aggregation API (FastAPI, PostgreSQL, Redis)
- `terminal/` — Bloomberg-style TUI for Dashtam (Textual, Typer)
- `cli/` — Future extractable CLI tool

---

## 1. Development Philosophy

**Core Principles** (apply to ALL projects):

- **Clean Architecture** — Separation of concerns, dependency inversion
- **Type Safety** — Type hints everywhere, strict mypy
- **Protocol-Based** — Structural typing with `Protocol` (NOT ABC)
- **Result Types** — Explicit error handling, no silent failures
- **Documentation-First** — Architecture decisions documented before coding
- **Test-Driven** — High coverage, meaningful tests

---

## 2. Modern Python Patterns

**CRITICAL**: All projects use Python 3.14+ features consistently.

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

## 3. Docker Containerization

**CRITICAL**: ALL development happens in Docker containers. No local Python environments.

### Common Patterns

```yaml
# Multi-stage Dockerfile with UV
FROM ghcr.io/astral-sh/uv:0.8.22-python3.14-trixie-slim AS base
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

## 4. Git Workflow

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
chore(deps): update httpx to 0.28.1
```

**Co-author** (required for AI-assisted commits):

```
Co-Authored-By: Warp <agent@warp.dev>
```

**Issue References**: Include `(#N)` for feature/fix commits. See Section 10 for full GitHub Issues workflow.

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

## 5. Code Quality Standards

### Ruff (Linting + Formatting)

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

## 6. Testing Philosophy

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

## 7. Environment Configuration

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

## 8. AI Agent Instructions

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

## 9. External References

- `~/references/Dashtam/` — Dashtam-specific planning documents
- `~/references/CLI/` — CLI/Terminal design documents

---

## 10. GitHub Issues Workflow

**CRITICAL**: All feature development is tracked via GitHub Issues. The local feature roadmap file is deprecated.

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
|----------|--------|--------|
| **Type** | `enhancement`, `bug`, `documentation`, `refactor`, `chore` | What kind of work |
| **Priority** | `priority:high`, `priority:medium`, `priority:lower` | Urgency level |
| **Feature** | `sse`, `auth`, `providers`, `sync`, `ai`, `terminal` | Feature area |
| **Status** | `status:in-progress`, `status:blocked`, `status:needs-review` | Track state |
| **Scope** | `breaking-change`, `security` | Special attention |

### Milestones

Milestones group related issues toward a specific release or outcome:

- **Version releases**: `v1.10.0`, `v2.0.0`
- **Feature sets**: `SSE Implementation`, `AI Integration`

Milestones show visual progress as issues close.

### Linking Conventions

| Where | Format | Example |
|-------|--------|--------|
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

**Last Updated**: 2026-01-18
