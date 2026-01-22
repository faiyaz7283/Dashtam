#!/usr/bin/env bash
#
# Release Rollback Script
# 
# Rollback a release based on its current phase.
# 
# Usage:
#   ./scripts/release-rollback.sh --project api --version 1.9.4 [OPTIONS]
#
# Phases:
#   1 - Release branch exists (not merged to development)
#   2 - PR created to development (not merged)
#   3 - Merged to development (not merged to main)
#   4 - Tagged and released (merged to main)
#
# Examples:
#   ./scripts/release-rollback.sh --project api --version 1.9.4
#   ./scripts/release-rollback.sh --project api --version 1.9.4 --dry-run
#   ./scripts/release-rollback.sh --project api --version 1.9.4 --phase 2 --yes
#   ./scripts/release-rollback.sh --project api --version 1.9.4 --dry-run --verbose
#

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✅${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $*"
}

log_error() {
    echo -e "${RED}❌${NC} $*" >&2
}

confirm() {
    local prompt="$1"
    if [[ "${DRY_RUN}" == "1" ]]; then
        log_info "[DRY-RUN] Would prompt: $prompt"
        return 0
    fi
    if [[ "${SKIP_CONFIRM:-0}" == "1" ]]; then
        return 0
    fi
    
    read -p "$(echo -e "${YELLOW}⚠️${NC}  $prompt (yes/no): ")" response
    if [[ "$response" != "yes" ]]; then
        log_error "Operation cancelled"
        exit 1
    fi
}

execute_command() {
    local cmd="$1"
    local description="$2"
    local show_output="${3:-0}"  # Optional: show actual output in dry-run
    
    if [[ "${DRY_RUN}" == "1" ]]; then
        echo ""
        echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
        log_info "[DRY-RUN] $description"
        echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
        echo -e "${BOLD}Command:${NC} $cmd"
        
        # If requested, try to show what the command would affect
        if [[ "$show_output" == "1" ]]; then
            echo -e "\n${BOLD}Current state:${NC}"
            eval "$cmd" 2>&1 || echo "  (would execute if not in dry-run)"
        fi
        
        echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
        echo ""
        return 0
    fi
    
    if [[ "${VERBOSE}" == "1" ]]; then
        log_info "Executing: $cmd"
    fi
    
    eval "$cmd"
}

usage() {
    cat << EOF
Usage: $(basename "$0") --project PROJECT --version VERSION [OPTIONS]

Rollback a release based on its current phase.

Required:
  --project PROJECT       Project name (api, terminal, jobs)
                          (auto-detected from current directory if not specified)
  --version VERSION       Version to rollback (X.Y.Z format)

Optional:
  --phase N              Force specific phase (1-4)
  --dry-run              Preview actions without executing
  --verbose              Show detailed output
  --yes                  Skip confirmation prompts
  --help                 Show this help message

Phases:
  1 - Release branch exists (not merged to development)
  2 - PR created to development (not merged)
  3 - Merged to development (not merged to main)
  4 - Tagged and released (merged to main)

Examples:
  $(basename "$0") --project api --version 1.9.4
  $(basename "$0") --project api --version 1.9.4 --dry-run
  $(basename "$0") --project api --version 1.9.4 --phase 2 --yes
  $(basename "$0") --project api --version 1.9.4 --dry-run --verbose

EOF
}

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

PROJECT=""
VERSION=""
PHASE=""
SKIP_CONFIRM=0
DRY_RUN=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --phase)
            PHASE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --yes)
            SKIP_CONFIRM=1
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Auto-detect project if not specified
if [[ -z "$PROJECT" ]]; then
    pwd_basename="$(basename "$PWD")"
    
    # Check if we're inside a project directory
    if [[ "$pwd_basename" == "api" || "$pwd_basename" == "terminal" || "$pwd_basename" == "jobs" ]]; then
        PROJECT="$pwd_basename"
        log_info "Auto-detected project from current directory: $PROJECT"
    # Check if PWD contains a project path
    elif [[ "$PWD" == */dashtam/api* ]]; then
        PROJECT="api"
        log_info "Auto-detected project from path: $PROJECT"
    elif [[ "$PWD" == */dashtam/terminal* ]]; then
        PROJECT="terminal"
        log_info "Auto-detected project from path: $PROJECT"
    elif [[ "$PWD" == */dashtam/jobs* ]]; then
        PROJECT="jobs"
        log_info "Auto-detected project from path: $PROJECT"
    fi
fi

# Validate required arguments
if [[ -z "$PROJECT" || -z "$VERSION" ]]; then
    log_error "Missing required arguments"
    log_error "PROJECT must be specified or auto-detected from current directory"
    usage
    exit 1
fi

# ==============================================================================
# VALIDATION
# ==============================================================================

log_info "Validating rollback for ${PROJECT} v${VERSION}..."

# Validate project
PROJECT_DIR="$META_REPO_ROOT/$PROJECT"
if [[ ! -d "$PROJECT_DIR" ]]; then
    log_error "Project directory not found: $PROJECT_DIR"
    exit 1
fi

# Validate version format
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format: $VERSION (expected X.Y.Z)"
    exit 1
fi

RELEASE_BRANCH="release/v$VERSION"
TAG_NAME="v$VERSION"

# ==============================================================================
# PHASE DETECTION
# ==============================================================================

detect_phase() {
    cd "$PROJECT_DIR"
    
    # Phase 4: Tag exists
    if git rev-parse "$TAG_NAME" &>/dev/null; then
        echo "4"
        return
    fi
    
    # Phase 3: Merged to development (check for commit with version)
    if git log development --oneline --grep="v$VERSION" --all | grep -q "v$VERSION"; then
        echo "3"
        return
    fi
    
    # Phase 2: PR exists (check via gh CLI)
    # Search by branch name, not text content
    if gh pr list --state all --head "v$VERSION" --json number | grep -q "number"; then
        echo "2"
        return
    fi
    
    # Phase 1: Release branch exists
    if git rev-parse --verify "$RELEASE_BRANCH" &>/dev/null; then
        echo "1"
        return
    fi
    
    # Not found
    echo "0"
}

if [[ -z "$PHASE" ]]; then
    PHASE=$(detect_phase)
    if [[ "$PHASE" == "0" ]]; then
        log_error "Release v$VERSION not found in any phase"
        exit 1
    fi
    log_info "Detected phase: $PHASE"
else
    # Validate manually specified phase
    DETECTED_PHASE=$(detect_phase)
    if [[ "$DETECTED_PHASE" == "0" ]]; then
        log_error "Release v$VERSION not found in any phase"
        log_error "Cannot use --phase with non-existent release"
        exit 1
    fi
    
    log_info "Detected phase: $DETECTED_PHASE"
    log_info "Manual override: Using phase $PHASE"
    
    # Warn if phase mismatch
    if [[ "$PHASE" != "$DETECTED_PHASE" ]]; then
        log_warning "⚠️  PHASE MISMATCH DETECTED!"
        log_warning "   Detected phase: $DETECTED_PHASE"
        log_warning "   Manual phase:   $PHASE"
        echo ""
        log_warning "Using wrong phase can cause issues:"
        log_warning "  - Phase too low: May not clean up properly"
        log_warning "  - Phase too high: May try operations that don't exist"
        echo ""
        if [[ "$DRY_RUN" != "1" ]]; then
            confirm "Continue with phase $PHASE anyway?"
        fi
    fi
fi

# ==============================================================================
# ROLLBACK STRATEGIES
# ==============================================================================

rollback_phase1() {
    log_info "Phase 1 Rollback: Delete release branch"
    
    cd "$PROJECT_DIR"
    
    # Check if branch exists locally
    if git rev-parse --verify "$RELEASE_BRANCH" &>/dev/null; then
        log_warning "Local branch '$RELEASE_BRANCH' exists"
        
        if [[ "$DRY_RUN" == "1" ]]; then
            # Show branch details
            echo ""
            log_info "Branch details:"
            git log --oneline "$RELEASE_BRANCH" -5 2>/dev/null || echo "  (branch exists)"
            echo ""
        fi
        
        confirm "Delete local branch?"
        execute_command "git branch -D '$RELEASE_BRANCH'" "Delete local branch $RELEASE_BRANCH"
        
        if [[ "$DRY_RUN" != "1" ]]; then
            log_success "Deleted local branch"
        fi
    else
        log_info "Local branch not found (already deleted or never created)"
    fi
    
    # Check if branch exists remotely
    if git ls-remote --heads origin "$RELEASE_BRANCH" | grep -q "$RELEASE_BRANCH"; then
        log_warning "Remote branch 'origin/$RELEASE_BRANCH' exists"
        confirm "Delete remote branch?"
        
        execute_command "git push origin --delete '$RELEASE_BRANCH'" "Delete remote branch $RELEASE_BRANCH"
        
        if [[ "$DRY_RUN" != "1" ]]; then
            log_success "Deleted remote branch"
        fi
    else
        log_info "Remote branch not found (already deleted or never pushed)"
    fi
    
    if [[ "$DRY_RUN" != "1" ]]; then
        log_success "Phase 1 rollback complete"
    fi
}

rollback_phase2() {
    log_info "Phase 2 Rollback: Close PR and delete branch"
    
    cd "$PROJECT_DIR"
    
    # Find PR number
    log_info "Searching for PR with branch: $RELEASE_BRANCH"
    # Extract branch name without 'release/' prefix for --head flag
    BRANCH_NAME="${RELEASE_BRANCH#release/}"
    PR_NUMBER=$(gh pr list --state all --head "$BRANCH_NAME" --json number --jq '.[0].number')
    
    if [[ -n "$PR_NUMBER" ]]; then
        log_warning "Found PR #$PR_NUMBER"
        
        if [[ "$DRY_RUN" == "1" ]]; then
            echo ""
            log_info "PR details:"
            gh pr view "$PR_NUMBER" --json title,state,headRefName,url --template '{{"Title: "}}{{.title}}{{"\n"}}State: {{.state}}{{"\n"}}Branch: {{.headRefName}}{{"\n"}}URL: {{.url}}{{"\n"}}'
            echo ""
        fi
        
        confirm "Close PR #$PR_NUMBER?"
        execute_command "gh pr close '$PR_NUMBER' --comment 'Rollback: Cancelling release v$VERSION' --delete-branch" "Close PR #$PR_NUMBER and delete branch"
        
        if [[ "$DRY_RUN" != "1" ]]; then
            log_success "Closed PR #$PR_NUMBER and deleted branch"
        fi
    else
        log_warning "PR not found (may have been closed or never created)"
        log_info "Attempting branch cleanup instead..."
        echo ""
        rollback_phase1
    fi
    
    if [[ "$DRY_RUN" != "1" ]]; then
        log_success "Phase 2 rollback complete"
    fi
}

rollback_phase3() {
    log_info "Phase 3 Rollback: Revert commit on development"
    
    cd "$PROJECT_DIR"
    
    # Find the release commit
    log_info "Searching for release commit on development branch..."
    RELEASE_COMMIT=$(git log development --oneline --grep="v$VERSION" --format="%H" -1)
    
    if [[ -z "$RELEASE_COMMIT" ]]; then
        log_error "Release commit not found on development"
        exit 1
    fi
    
    log_warning "Found release commit: $RELEASE_COMMIT"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        echo ""
        log_info "Commit details:"
        git show --stat --oneline "$RELEASE_COMMIT"
        echo ""
        log_info "This will create a NEW revert commit that undoes these changes"
        log_info "(Original commit stays in history - git revert is non-destructive)"
        echo ""
    fi
    
    log_warning "This will create a revert commit on development branch (both remote and local)"
    confirm "Revert commit $RELEASE_COMMIT on development?"
    
    # Ensure we're on development
    execute_command "git checkout development" "Switch to development branch"
    execute_command "git pull origin development" "Pull latest changes"
    
    # Create revert commit
    execute_command "git revert '$RELEASE_COMMIT' --no-edit -m 'Rollback: Revert release v$VERSION'" "Create revert commit"
    
    if [[ "$DRY_RUN" != "1" ]]; then
        log_warning "Revert commit created locally"
    fi
    
    confirm "Push revert commit to origin/development?"
    execute_command "git push origin development" "Push revert commit to remote"
    
    if [[ "$DRY_RUN" != "1" ]]; then
        log_success "Pushed revert commit to development"
    fi
    
    # Close main PR if exists
    log_info "Checking for open PR to main..."
    MAIN_PR=$(gh pr list --base main --head development --json number --jq '.[0].number')
    if [[ -n "$MAIN_PR" ]]; then
        log_warning "Found PR #$MAIN_PR to main"
        
        if [[ "$DRY_RUN" == "1" ]]; then
            echo ""
            log_info "PR details:"
            gh pr view "$MAIN_PR" --json title,state,url --template '{{"Title: "}}{{.title}}{{"\n"}}State: {{.state}}{{"\n"}}URL: {{.url}}{{"\n"}}'
            echo ""
        fi
        
        confirm "Close PR #$MAIN_PR?"
        execute_command "gh pr close '$MAIN_PR' --comment 'Rollback: Release v$VERSION reverted on development'" "Close PR #$MAIN_PR"
        
        if [[ "$DRY_RUN" != "1" ]]; then
            log_success "Closed PR #$MAIN_PR"
        fi
    else
        log_info "No open PR to main found"
    fi
    
    if [[ "$DRY_RUN" != "1" ]]; then
        log_success "Phase 3 rollback complete"
    fi
}

rollback_phase4() {
    log_error "Phase 4 Rollback: Tag and release exist"
    echo ""
    log_warning "⚠️  IMPORTANT: Do NOT delete tags or releases"
    log_warning "This breaks history and causes issues for users who pulled the tag"
    echo ""
    log_info "Recommended approach:"
    echo ""
    echo "  1. Create a fix release (e.g., v${VERSION%.*}.$((${VERSION##*.} + 1)))"
    echo "     - Run: make release VERSION=${VERSION%.*}.$((${VERSION##*.} + 1))"
    echo ""
    echo "  2. OR revert on main and create new release:"
    echo "     - Checkout main: git checkout main && git pull"
    echo "     - Find commit: git log --oneline | grep 'v$VERSION'"
    echo "     - Revert: git revert <commit> --no-edit"
    echo "     - Push: git push origin main"
    echo "     - Tag new version: git tag -a v${VERSION%.*}.$((${VERSION##*.} + 1)) -m 'Rollback v$VERSION'"
    echo "     - Push tag: git push origin v${VERSION%.*}.$((${VERSION##*.} + 1))"
    echo "     - Create release: gh release create v${VERSION%.*}.$((${VERSION##*.} + 1))"
    echo ""
    log_warning "Manual intervention required for Phase 4"
    exit 1
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

log_info "==================================================="
if [[ "$DRY_RUN" == "1" ]]; then
    log_info "Release Rollback - Phase $PHASE [DRY-RUN MODE]"
else
    log_info "Release Rollback - Phase $PHASE"
fi
log_info "==================================================="
log_info "Project: $PROJECT"
log_info "Version: v$VERSION"
log_info "Phase:   $PHASE"
if [[ "$DRY_RUN" == "1" ]]; then
    log_info "Mode:    DRY-RUN (no changes will be made)"
fi
if [[ "$VERBOSE" == "1" ]]; then
    log_info "Verbose: Enabled"
fi
log_info "==================================================="
echo ""

case "$PHASE" in
    1)
        rollback_phase1
        ;;
    2)
        rollback_phase2
        ;;
    3)
        rollback_phase3
        ;;
    4)
        rollback_phase4
        ;;
    *)
        log_error "Invalid phase: $PHASE (must be 1-4)"
        exit 1
        ;;
esac

log_success "Rollback complete for v$VERSION (Phase $PHASE)"
