# Dashtam Environment Flow Diagrams

## Development Environment Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEVELOPMENT WORKFLOW                         │
└─────────────────────────────────────────────────────────────────────┘

  Developer runs: make up
         │
         ▼
  ┌──────────────────────────────────────┐
  │   Docker Compose reads:              │
  │   • docker-compose.yml               │
  │   • .env file                        │
  └──────────────────────────────────────┘
         │
         ▼
  ┌─────────────────────────────────────────────────────────────┐
  │              CONTAINERS START (4 services)                  │
  ├─────────────────────────────────────────────────────────────┤
  │                                                             │
  │  ┌─────────────────┐  ┌─────────────────┐                   │
  │  │ dashtam-postgres│  │  dashtam-redis  │                   │
  │  │                 │  │                 │                   │
  │  │ DB: dashtam     │  │ Cache index: 0  │                   │
  │  │ User: dashtam_  │  │                 │                   │
  │  │       user      │  │                 │                   │
  │  └─────────────────┘  └─────────────────┘                   │
  │         ▲                     ▲                             │
  │         │                     │                             │
  │         └─────────┬───────────┘                             │
  │                   │                                         │
  │  ┌────────────────┴────────────────┐  ┌─────────────────┐   │
  │  │      dashtam-app                │  │ dashtam-callback│   │
  │  │      (port 8000)                │  │  (port 8182)    │   │
  │  │                                 │  │                 │   │
  │  │  1. Container starts            │  │ OAuth callback  │   │
  │  │  2. Runs: uv run python         │  │ server          │   │
  │  │     src/core/init_db.py         │  │                 │   │
  │  │  3. init_db.py:                 │  │                 │   │
  │  │     ├─ Load .env settings       │  │                 │   │
  │  │     ├─ Connect to dashtam DB    │  │                 │   │
  │  │     ├─ Import all models        │  │                 │   │
  │  │     ├─ Create tables if missing │  │                 │   │
  │  │     └─ Log success ✓            │  │                 │   │
  │  │  4. Starts FastAPI app          │  │                 │   │
  │  │  5. Hot reload enabled          │  │                 │   │
  │  │                                 │  │                 │   │
  │  └─────────────────────────────────┘  └─────────────────┘   │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────┐
  │  App Running & Ready                 │
  │  • https://localhost:8000            │
  │  • Auto-reload on code changes       │
  │  • Dev database has persistent data  │
  └──────────────────────────────────────┘
```

---

## Test Environment Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TESTING WORKFLOW                             │
└─────────────────────────────────────────────────────────────────────┘

  Developer runs: make test-setup
         │
         ▼
  ┌──────────────────────────────────────┐
  │  Docker Compose reads:               │
  │  • docker-compose.yml                │
  │  • docker-compose.test.yml (overlay) │
  │  • .env.test (--env-file flag)       │
  └──────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────┐
  │  Dev containers STOP                 │
  │  (if running)                        │
  └──────────────────────────────────────┘
         │
         ▼
  ┌────────────────────────────────────────────────┐
  │     TEST CONTAINERS START (with overrides)     │
  ├────────────────────────────────────────────────┤
  │                                                │
  │  ┌──────────────────────────────────────────┐  │
  │  │        dashtam-postgres                  │  │
  │  │                                          │  │
  │  │  Environment Override:                   │  │
  │  │  • POSTGRES_DB=dashtam_test              │  │
  │  │  • POSTGRES_USER=dashtam_test_user       │  │
  │  │                                          │  │
  │  │  BOTH databases exist now:               │  │
  │  │  ├─ dashtam (dev data untouched)         │  │
  │  │  └─ dashtam_test (for testing)           │  │
  │  │                                          │  │
  │  │  Init script runs:                       │  │
  │  │  docker/init-test-db.sh                  │  │
  │  │  ├─ Creates dashtam_test_user            │  │
  │  │  ├─ Grants permissions                   │  │
  │  │  └─ Enables UUID extension               │  │
  │  └──────────────────────────────────────────┘  │
  │         ▲                    ▲                 │
  │         │                    │                 │
  │  ┌──────┴──────────┐  ┌──────┴──────────┐      │
  │  │ dashtam-app     │  │ dashtam-redis   │      │
  │  │                 │  │                 │      │
  │  │ Overrides:      │  │ Cache index: 1  │      │
  │  │ • Command:      │  │ (different)     │      │
  │  │   sleep infinity│  │                 │      │
  │  │ • Mounts:       │  │                 │      │
  │  │   .env.test     │  │                 │      │
  │  │   as .env       │  │                 │      │
  │  │ • Env vars:     │  │                 │      │
  │  │   DATABASE_URL= │  │                 │      │
  │  │   ...test_user  │  │                 │      │
  │  │   @postgres:    │  │                 │      │
  │  │   5432/         │  │                 │      │
  │  │   dashtam_test  │  │                 │      │
  │  │                 │  │                 │      │
  │  │ App NOT running │  │                 │      │
  │  │ (sleep mode)    │  │                 │      │
  │  └─────────────────┘  └─────────────────┘      │
  │                                                │
  └────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────┐
  │  Makefile executes:                                      │
  │  docker-compose exec app                                 │
  │    uv run python src/core/init_test_db.py                │
  └──────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────┐
  │           init_test_db.py runs                           │
  ├──────────────────────────────────────────────────────────┤
  │                                                          │
  │  1. Load TestSettings (from .env)                        │
  │     • Actually reading .env.test (mounted as .env)       │
  │                                                          │
  │  2. ⚠️  SAFETY CHECK                                     │
  │     ├─ ENVIRONMENT == "testing"? ✓                       │
  │     ├─ DATABASE_URL contains "test"? ✓                   │
  │     └─ TESTING == true? ✓                                │
  │                                                          │
  │  3. Connect to dashtam_test database                     │
  │     • Verify database name contains "test"               │
  │                                                          │
  │  4. Apply test optimizations                             │
  │     ├─ SET synchronous_commit = OFF                      │
  │     ├─ SET fsync = OFF (if allowed)                      │
  │     └─ SET full_page_writes = OFF (if allowed)           │
  │                                                          │
  │  5. Import all models                                    │
  │     ├─ from src.models.user import User                  │
  │     ├─ from src.models.provider import Provider,         │
  │     │   ProviderConnection, ProviderToken, AuditLog      │
  │     └─ Models register with SQLModel.metadata            │
  │                                                          │
  │  6. 🧹 DROP all existing tables                          │
  │     • Ensures clean slate for every test run             │
  │                                                          │
  │  7. 🏗️  CREATE all tables fresh                          │
  │     ├─ users                                             │
  │     ├─ providers                                         │
  │     ├─ provider_connections                              │
  │     ├─ provider_tokens                                   │
  │     └─ provider_audit_logs                               │
  │                                                          │
  │  8. Verify all tables exist                              │
  │                                                          │
  │  9. ✅ Success - Test DB ready!                          │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
         │
         ▼
  ┌───────────────────────────────────────┐
  │  Test Environment Ready               │
  │  • Clean database                     │
  │  • App container running (sleep mode) │
  │  • Ready for pytest execution         │
  └───────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────┐
  │  Developer runs: make test-unit                          │
  └──────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────┐
  │  Makefile executes:                                      │
  │  docker-compose exec app                                 │
  │    uv run pytest tests/unit/ -v                          │
  └──────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────┐
  │           Pytest runs inside container                   │
  ├──────────────────────────────────────────────────────────┤
  │                                                          │
  │  • Uses test database (dashtam_test)                     │
  │  • Fixtures from conftest.py                             │
  │  • Test config from test_config.py                       │
  │  • Isolated from dev database                            │
  │                                                          │
  │  Results: X passed, Y failed                             │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

---

## Database State Comparison

```
┌─────────────────────────────────────────────────────────────────────┐
│            POSTGRESQL CONTAINER STATE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────────────────────────────────────────────────────┐      │
│   │         PostgreSQL Instance (Single Container)           │      │
│   ├──────────────────────────────────────────────────────────┤      │
│   │                                                          │      │
│   │  ┌─────────────────────┐   ┌──────────────────────┐      │      │
│   │  │   DATABASE: dashtam │   │DATABASE: dashtam_test│      │      │
│   │  │   (Development)     │   │    (Testing)         │      │      │
│   │  ├─────────────────────┤   ├──────────────────────┤      │      │
│   │  │                     │   │                      │      │      │
│   │  │ Owner: dashtam_user │   │ Owner: dashtam_      │      │      │
│   │  │                     │   │        test_user     │      │      │
│   │  │                     │   │                      │      │      │
│   │  │ Tables:             │   │ Tables:              │      │      │
│   │  │ • users             │   │ • users              │      │      │
│   │  │ • providers         │   │ • providers          │      │      │
│   │  │ • provider_         │   │ • provider_          │      │      │
│   │  │   connections       │   │   connections        │      │      │
│   │  │ • provider_tokens   │   │ • provider_tokens    │      │      │
│   │  │ • provider_audit_   │   │ • provider_audit_    │      │      │
│   │  │   logs              │   │   logs               │      │      │
│   │  │                     │   │                      │      │      │
│   │  │ Data:               │   │ Data:                │      │      │
│   │  │ • Persistent        │   │ • Dropped on each    │      │      │
│   │  │ • Survives restarts │   │   test-setup         │      │      │
│   │  │ • Real OAuth tokens │   │ • Always clean       │      │      │
│   │  │ • Provider configs  │   │ • Mock data only     │      │      │
│   │  │                     │   │                      │      │      │
│   │  └─────────────────────┘   └──────────────────────┘      │      │
│   │                                                          │      │
│   │  COMPLETELY ISOLATED - No data sharing!                  │      │
│   │                                                          │      │
│   └──────────────────────────────────────────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Environment Switching Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│              SWITCHING BETWEEN ENVIRONMENTS                         │
└─────────────────────────────────────────────────────────────────────┘

Scenario 1: Dev → Test → Dev
════════════════════════════════════════════════════════════════

  ┌──────────────┐
  │ Dev Running  │
  │ make up      │
  └──────┬───────┘
         │
         │ (You run: make test-setup)
         ▼
  ┌──────────────┐
  │ Dev STOPS    │
  │ Containers   │
  │ restart with │
  │ test config  │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │ Test Running │
  │ Dev DB still │
  │ has data!    │
  └──────┬───────┘
         │
         │ (You run: make test-clean)
         ▼
  ┌──────────────┐
  │ Test STOPS   │
  │ Test DB      │
  │ destroyed    │
  └──────┬───────┘
         │
         │ (You run: make up)
         ▼
  ┌──────────────┐
  │ Dev Running  │
  │ AGAIN!       │
  │ All dev data │
  │ intact! ✓    │
  └──────────────┘


Scenario 2: What NOT to Do
════════════════════════════════════════════════════════════════

  ❌ Running: make up && make test-setup
     (in different terminals simultaneously)
  
  Result: Containers conflict!
  Both try to use same container names.
  
  Solution: Stop one before starting the other.
```

---

## Configuration Loading Hierarchy

```
┌─────────────────────────────────────────────────────────────────────┐
│                 DEVELOPMENT CONFIGURATION                           │
└─────────────────────────────────────────────────────────────────────┘

  Docker Compose Layer
  ┌──────────────────────────────────────────────────┐
  │ docker-compose.yml                               │
  │                                                  │
  │ environment:                                     │
  │   DATABASE_URL: postgresql+asyncpg://...         │
  │                 ${POSTGRES_USER}:${POSTGRES_     │
  │                 PASSWORD}@postgres:5432/         │
  │                 ${POSTGRES_DB}                   │
  └────────────────────┬─────────────────────────────┘
                       │ (reads from)
                       ▼
  Environment File Layer
  ┌──────────────────────────────────────────────────┐
  │ .env                                             │
  │                                                  │
  │ POSTGRES_DB=dashtam                              │
  │ POSTGRES_USER=dashtam_user                       │
  │ POSTGRES_PASSWORD=secure_password_change_me      │
  │ ENVIRONMENT=development                          │
  │ DEBUG=true                                       │
  └────────────────────┬─────────────────────────────┘
                       │ (loaded by)
                       ▼
  Pydantic Settings Layer
  ┌──────────────────────────────────────────────────┐
  │ src/core/config.py                               │
  │                                                  │
  │ class Settings(BaseSettings):                    │
  │     DATABASE_URL: str                            │
  │     ENVIRONMENT: str = "production"              │
  │     DEBUG: bool = False                          │
  │                                                  │
  │     model_config = SettingsConfigDict(           │
  │         env_file=".env",                         │
  │     )                                            │
  └────────────────────┬─────────────────────────────┘
                       │ (used by)
                       ▼
  Application Layer
  ┌──────────────────────────────────────────────────┐
  │ src/main.py, src/core/init_db.py                 │
  │                                                  │
  │ from src.core.config import settings             │
  │                                                  │
  │ settings.DATABASE_URL  ← Final value!            │
  └──────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                  TEST CONFIGURATION                                 │
└─────────────────────────────────────────────────────────────────────┘

  Docker Compose Layer
  ┌──────────────────────────────────────────────────┐
  │ docker-compose.test.yml (OVERRIDES base)         │
  │                                                  │
  │ environment:                                     │
  │   DATABASE_URL: postgresql+asyncpg://            │
  │                 ${TEST_POSTGRES_USER}:           │
  │                 ${TEST_POSTGRES_PASSWORD}@       │
  │                 postgres:5432/                   │
  │                 ${TEST_POSTGRES_DB}              │
  │   ENVIRONMENT: testing                           │
  └────────────────────┬─────────────────────────────┘
                       │ (reads from)
                       ▼
  Environment File Layer
  ┌──────────────────────────────────────────────────┐
  │ .env.test (via --env-file flag)                  │
  │                                                  │
  │ TEST_POSTGRES_DB=dashtam_test                    │
  │ TEST_POSTGRES_USER=dashtam_test_user             │
  │ TEST_POSTGRES_PASSWORD=test_password             │
  │ ENVIRONMENT=testing                              │
  │ TESTING=true                                     │
  │ DEBUG=true                                       │
  │                                                  │
  │ (Also mounted as /app/.env inside container!)    │
  └────────────────────┬─────────────────────────────┘
                       │ (loaded by)
                       ▼
  Pydantic Settings Layer
  ┌──────────────────────────────────────────────────┐
  │ tests/test_config.py                             │
  │                                                  │
  │ class TestSettings(Settings):                    │
  │     TESTING: bool = True                         │
  │     DISABLE_EXTERNAL_CALLS: bool = True          │
  │                                                  │
  │     model_config = SettingsConfigDict(           │
  │         env_file=".env",  ← reads .env.test!     │
  │     )                                            │
  └────────────────────┬─────────────────────────────┘
                       │ (used by)
                       ▼
  Test Layer
  ┌──────────────────────────────────────────────────┐
  │ src/core/init_test_db.py, tests/*                │
  │                                                  │
  │ from tests.test_config import get_test_settings  │
  │                                                  │
  │ test_settings.DATABASE_URL  ← Test DB!           │
  └──────────────────────────────────────────────────┘
```

---

## Key Takeaways

### ✅ What You Need to Remember

1. **Dev and test use the SAME containers** but with different configurations
2. **Dev data is NEVER lost** when running tests (different database)
3. **Test data is ALWAYS fresh** (dropped and recreated each time)
4. **You cannot run dev and test simultaneously** (container name conflicts)
5. **Switching is easy**: `make test-clean` → `make up`

### ⚠️  Critical Safety Features

1. **init_test_db.py has safety checks** - won't run on production
2. **Test database name must contain "test"** - verified before operations
3. **ENVIRONMENT must be "testing"** - double-checked
4. **Tables are dropped first** - ensures clean state every time

### 🎯 Best Practices

1. **Always run `make test-setup` first** before running tests
2. **Use `make test-clean`** when done testing
3. **Don't manually connect to test database** - let scripts handle it
4. **Dev database persists** - your OAuth tokens and test data are safe
