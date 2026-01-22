#!/opt/homebrew/bin/bash
#
# release.sh - Automated Release Script for Dashtam Projects
#
# Requires: Bash 4.0+ (for associative arrays)
#
# Purpose:
#   Automates the release process for Dashtam projects (api, terminal, jobs).
#   Creates release branch, updates version, generates CHANGELOG, creates PRs.
#   Works with GitHub Actions for event-driven PR merging and tagging.
#
# Usage:
#   # From meta repo root - explicit project
#   make release PROJECT=api VERSION=1.2.0
#   ./scripts/release.sh --project api --version 1.2.0
#
#   # From project directory - auto-detect
#   cd ~/dashtam/api
#   make release VERSION=1.2.0
#   ../scripts/release.sh --version 1.2.0
#
#   # Interactive mode (prompts for version bump)
#   make release PROJECT=api
#   ./scripts/release.sh --project api
#
#   # Dry-run mode (preview without executing)
#   make release PROJECT=api VERSION=1.2.0 DRY_RUN=1
#   ./scripts/release.sh --project api --version 1.2.0 --dry-run
#
# Flags:
#   --project, -p       Project name (api, terminal, jobs)
#   --version, -v       Version to release (X.Y.Z format)
#   --milestone, -m     Milestone to validate (optional)
#   --dry-run           Preview changes without executing
#   --verbose           Show detailed output (CHANGELOG content, commands)
#   --yes               Skip all confirmation prompts
#   --help, -h          Show this help message
#
# Environment Variables:
#   PROJECT             Project name (overridden by --project)
#   VERSION             Version to release (overridden by --version)
#   MILESTONE           Milestone to validate (overridden by --milestone)
#   DRY_RUN=1           Enable dry-run mode
#   VERBOSE=1           Enable verbose output
#   YES=1               Skip confirmation prompts
#
# Examples:
#   # Release API v1.2.0 with milestone validation
#   ./scripts/release.sh --project api --version 1.2.0 --milestone "v1.2.0"
#
#   # Interactive release (prompts for version bump type)
#   ./scripts/release.sh --project terminal
#
#   # Dry-run to preview changes
#   ./scripts/release.sh --project jobs --version 0.2.0 --dry-run
#
# Release Flow:
#   Phase 1 (This Script - Preparation):
#     1. Pre-flight validation (git state, branch, milestone, CI)
#     2. Version validation (format, increment, uniqueness)
#     3. Interactive version bump (if version not specified)
#     4. Update pyproject.toml version
#     5. Run uv lock in dev container (with validation)
#     6. Generate CHANGELOG entry from milestone issues
#     7. Create release/vX.Y.Z branch
#     8. Commit and push changes
#     9. Create PR to development with 'automated-release' label
#     10. Exit (GitHub Actions takes over)
#
#   Phase 2 (GitHub Actions - Event-Driven):
#     - Triggered when PR to development is merged
#     - Creates PR from development → main
#
#   Phase 3 (GitHub Actions - Finalization):
#     - Triggered when PR to main is merged
#     - Tags release vX.Y.Z
#     - Creates GitHub Release (with CHANGELOG content)
#     - Syncs main → development
#     - Removes 'automated-release' label
#
# Author: Dashtam Team
# Last Updated: 2026-01-22

set -euo pipefail

# =============================================================================
# SETUP
# =============================================================================

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

readonly RELEASE_LABEL="automated-release"
readonly REQUIRED_BRANCH="development"

# Project-specific main container service names
# Maps project name to the primary container service name for running uv lock
declare -A PROJECT_MAIN_CONTAINER=(
    [api]="app"
    [terminal]=""
    [jobs]="worker"
)

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================

# Command-line arguments (will be set by parse_args)
ARG_PROJECT=""
ARG_VERSION=""
ARG_MILESTONE=""
ARG_DRY_RUN="${DRY_RUN:-0}"
ARG_VERBOSE="${VERBOSE:-0}"
ARG_YES="${YES:-0}"

# Detected/computed values (set during execution)
PROJECT_NAME=""
PROJECT_PATH=""
CURRENT_VERSION=""
NEW_VERSION=""
RELEASE_BRANCH=""
PR_NUMBER=""

# Cleanup actions (populated during execution for rollback)
CLEANUP_ACTIONS=()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

#
# show_help - Display help message
#
show_help() {
    cat << EOF
Release Automation Script for Dashtam Projects

Usage:
  $(basename "$0") [OPTIONS]

Options:
  -p, --project PROJECT   Project name (api, terminal, jobs)
  -v, --version VERSION   Version to release (X.Y.Z format)
  -m, --milestone NAME    Milestone to validate (optional)
  --dry-run               Preview changes without executing
  --verbose               Show detailed output (CHANGELOG, commands)
  --yes                   Skip all confirmation prompts
  -h, --help              Show this help message

Examples:
  # Release API v1.2.0
  $(basename "$0") --project api --version 1.2.0

  # Interactive release (prompts for version)
  $(basename "$0") --project terminal

  # Dry-run to preview changes
  $(basename "$0") --project jobs --version 0.2.0 --dry-run

Environment Variables:
  PROJECT        Project name (overridden by --project)
  VERSION        Version to release (overridden by --version)
  MILESTONE      Milestone to validate (overridden by --milestone)
  DRY_RUN=1      Enable dry-run mode
  VERBOSE=1      Enable verbose output
  YES=1          Skip confirmation prompts

EOF
}

#
# parse_args - Parse command-line arguments
#
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--project)
                ARG_PROJECT="$2"
                shift 2
                ;;
            -v|--version)
                ARG_VERSION="$2"
                shift 2
                ;;
            -m|--milestone)
                ARG_MILESTONE="$2"
                shift 2
                ;;
            --dry-run)
                ARG_DRY_RUN=1
                shift
                ;;
            --verbose)
                ARG_VERBOSE=1
                shift
                ;;
            --yes)
                ARG_YES=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1\nUse --help for usage information"
                ;;
        esac
    done
    
    # Use environment variables as fallback
    ARG_PROJECT="${ARG_PROJECT:-${PROJECT:-}}"
    ARG_VERSION="${ARG_VERSION:-${VERSION:-}}"
    ARG_MILESTONE="${ARG_MILESTONE:-${MILESTONE:-}}"
    
    # Export for use in other functions
    export DRY_RUN="$ARG_DRY_RUN"
    export VERBOSE="$ARG_VERBOSE"
    export YES="$ARG_YES"
}

#
# detect_project - Detect project from current directory or argument
#
detect_project() {
    local project="$ARG_PROJECT"
    
    # If no project specified, try to detect from current directory
    if [[ -z "$project" ]]; then
        local pwd_basename
        pwd_basename="$(basename "$PWD")"
        
        # Check if we're inside a project directory
        if [[ "$pwd_basename" == "api" || "$pwd_basename" == "terminal" || "$pwd_basename" == "jobs" ]]; then
            project="$pwd_basename"
            log_info "Auto-detected project from current directory: $project"
        # Check if PWD contains a project path
        elif [[ "$PWD" == */dashtam/api* ]]; then
            project="api"
            log_info "Auto-detected project from path: $project"
        elif [[ "$PWD" == */dashtam/terminal* ]]; then
            project="terminal"
            log_info "Auto-detected project from path: $project"
        elif [[ "$PWD" == */dashtam/jobs* ]]; then
            project="jobs"
            log_info "Auto-detected project from path: $project"
        else
            log_error "Cannot detect project. Use: --project <api|terminal|jobs>"
        fi
    fi
    
    # Validate project name
    case "$project" in
        api|terminal|jobs)
            PROJECT_NAME="$project"
            PROJECT_PATH="$DASHTAM_ROOT/$project"
            ;;
        *)
            log_error "Invalid project: $project\nValid projects: api, terminal, jobs"
            ;;
    esac
    
    # Validate project path exists
    if [[ ! -d "$PROJECT_PATH" ]]; then
        log_error "Project directory not found: $PROJECT_PATH"
    fi
    
    log_success "Project: $PROJECT_NAME"
}

#
# get_current_version - Read current version from pyproject.toml
#
get_current_version() {
    local pyproject="$PROJECT_PATH/pyproject.toml"
    
    if [[ ! -f "$pyproject" ]]; then
        log_error "pyproject.toml not found: $pyproject"
    fi
    
    CURRENT_VERSION=$(grep '^version = ' "$pyproject" | cut -d'"' -f2)
    
    if [[ -z "$CURRENT_VERSION" ]]; then
        log_error "Could not read version from pyproject.toml"
    fi
    
    log_info "Current version: $CURRENT_VERSION"
}

#
# determine_new_version - Determine new version (interactive or from argument)
#
determine_new_version() {
    if [[ -n "$ARG_VERSION" ]]; then
        NEW_VERSION="$ARG_VERSION"
    else
        # Interactive mode - prompt for version bump
        echo ""
        echo "Current version: $CURRENT_VERSION"
        echo ""
        echo "Version bump options:"
        echo "  1) major  (X.0.0)"
        echo "  2) minor  (x.Y.0)"
        echo "  3) patch  (x.y.Z)"
        echo "  4) custom (specify version)"
        echo ""
        read -rp "Select bump type [1-4]: " bump_choice
        
        # Parse current version
        IFS='.' read -ra version_parts <<< "$CURRENT_VERSION"
        local major="${version_parts[0]}"
        local minor="${version_parts[1]}"
        local patch="${version_parts[2]}"
        
        case "$bump_choice" in
            1|major)
                NEW_VERSION="$((major + 1)).0.0"
                ;;
            2|minor)
                NEW_VERSION="${major}.$((minor + 1)).0"
                ;;
            3|patch)
                NEW_VERSION="${major}.${minor}.$((patch + 1))"
                ;;
            4|custom)
                read -rp "Enter custom version (X.Y.Z): " NEW_VERSION
                ;;
            *)
                log_error "Invalid choice: $bump_choice"
                ;;
        esac
    fi
    
    log_info "New version: $NEW_VERSION"
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

#
# validate_prerequisites - Check required tools are installed
#
validate_prerequisites() {
    log_info "${EMOJI_CHECK} Checking prerequisites..."
    
    check_dependency "git" "Install Git: https://git-scm.com/"
    check_dependency "gh" "Install GitHub CLI: https://cli.github.com/"
    check_dependency "docker" "Install Docker: https://docs.docker.com/get-docker/"
    check_dependency "jq" "Install jq: https://jqlang.github.io/jq/download/"
    
    log_success "All prerequisites installed"
}

#
# validate_git_state - Validate git repository state
#
validate_git_state() {
    log_info "${EMOJI_CHECK} Validating git state..."
    
    cd "$PROJECT_PATH" || log_error "Failed to cd to $PROJECT_PATH"
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_error "Uncommitted changes detected. Commit or stash first.\n  Run: git status"
    fi
    
    # Check current branch
    local current_branch
    current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "$REQUIRED_BRANCH" ]]; then
        log_error "Must be on $REQUIRED_BRANCH branch (currently on $current_branch)\n  Run: git checkout $REQUIRED_BRANCH"
    fi
    
    # Check if up to date with remote
    git fetch origin "$REQUIRED_BRANCH" --quiet
    local local_commit
    local remote_commit
    local_commit=$(git rev-parse HEAD)
    remote_commit=$(git rev-parse "origin/$REQUIRED_BRANCH")
    
    if [[ "$local_commit" != "$remote_commit" ]]; then
        # Determine if ahead, behind, or diverged
        local ahead
        local behind
        ahead=$(git rev-list --count "origin/$REQUIRED_BRANCH"..HEAD)
        behind=$(git rev-list --count HEAD.."origin/$REQUIRED_BRANCH")
        
        if [[ "$ahead" -gt 0 && "$behind" -gt 0 ]]; then
            log_error "Local $REQUIRED_BRANCH has diverged from origin/$REQUIRED_BRANCH\n  Ahead: $ahead commits, Behind: $behind commits\n  Run: git pull --rebase origin $REQUIRED_BRANCH"
        elif [[ "$ahead" -gt 0 ]]; then
            log_error "Local $REQUIRED_BRANCH is ahead of origin/$REQUIRED_BRANCH by $ahead commit(s)\n  Run: git push origin $REQUIRED_BRANCH"
        elif [[ "$behind" -gt 0 ]]; then
            log_error "Local $REQUIRED_BRANCH is behind origin/$REQUIRED_BRANCH by $behind commit(s)\n  Run: git pull origin $REQUIRED_BRANCH"
        fi
    fi
    
    log_success "Git state valid"
}

#
# validate_version - Validate new version format and increment
#
validate_version() {
    log_info "${EMOJI_CHECK} Validating version..."
    
    # Validate format
    if ! validate_semver "$NEW_VERSION"; then
        log_error "Invalid version format: $NEW_VERSION\n  Must be semantic version (X.Y.Z)"
    fi
    
    # Validate increment (new > current)
    if ! version_compare "$NEW_VERSION" "$CURRENT_VERSION"; then
        log_error "New version ($NEW_VERSION) must be greater than current ($CURRENT_VERSION)"
    fi
    
    # Validate organic increment (only valid semver bumps)
    if ! validate_version_increment "$NEW_VERSION" "$CURRENT_VERSION" 2>&1; then
        # Error message already printed by validate_version_increment
        log_error "Invalid version increment. See validation details above."
    fi
    
    # Check if version tag already exists
    cd "$PROJECT_PATH" || exit 1
    if git tag | grep -q "^v$NEW_VERSION$"; then
        log_error "Version tag already exists: v$NEW_VERSION\n  Run: git tag -l 'v*' to see existing tags"
    fi
    
    log_success "Version valid: $CURRENT_VERSION → $NEW_VERSION"
}

#
# validate_milestone - Validate milestone issues are closed (if specified)
#
validate_milestone() {
    if [[ -z "$ARG_MILESTONE" ]]; then
        log_info "No milestone specified, skipping validation"
        return 0
    fi
    
    log_info "${EMOJI_CHECK} Validating milestone: $ARG_MILESTONE..."
    
    cd "$PROJECT_PATH" || exit 1
    
    # Get repository name
    local repo_name
    repo_name=$(basename "$PROJECT_PATH")
    
    # Check for open issues in milestone
    local open_issues
    open_issues=$(gh issue list \
        --repo "faiyaz7283/dashtam-$repo_name" \
        --milestone "$ARG_MILESTONE" \
        --state open \
        --limit 1 \
        --json number \
        --jq 'length')
    
    if [[ "$open_issues" -gt 0 ]]; then
        log_warning "Milestone '$ARG_MILESTONE' has open issues"
        if ! confirm "Continue anyway?"; then
            log_error "Release cancelled by user"
        fi
    else
        log_success "Milestone '$ARG_MILESTONE' has no open issues"
    fi
}

#
# validate_commits_since_last_release - Ensure meaningful changes exist
#
validate_commits_since_last_release() {
    log_info "${EMOJI_CHECK} Validating commits since last release..."
    
    cd "$PROJECT_PATH" || exit 1
    
    # Find last release tag
    local last_tag
    last_tag=$(git tag -l 'v*' --sort=-version:refname | head -n1)
    
    if [[ -z "$last_tag" ]]; then
        log_info "No previous release tags found (first release)"
        return 0
    fi
    
    # Count commits since last tag
    local commit_count
    commit_count=$(git rev-list "${last_tag}"..HEAD --count)
    
    if [[ "$commit_count" -eq 0 ]]; then
        log_error "No commits since last release ($last_tag)\n  Nothing to release. Development is already at the latest released version."
    fi
    
    # Show commit summary
    log_info "Commits since $last_tag: $commit_count"
    
    # Get commit types (from conventional commits)
    local feat_count
    local fix_count
    local docs_count
    local other_count
    feat_count=$(git log "${last_tag}"..HEAD --oneline | grep -c '^[a-f0-9]\+ feat' || true)
    fix_count=$(git log "${last_tag}"..HEAD --oneline | grep -c '^[a-f0-9]\+ fix' || true)
    docs_count=$(git log "${last_tag}"..HEAD --oneline | grep -c '^[a-f0-9]\+ docs' || true)
    other_count=$(git log "${last_tag}"..HEAD --oneline | grep -cE '^[a-f0-9]\+ (chore|test|refactor|perf|ci|style)' || true)
    
    # Show breakdown
    echo "  Commit breakdown:"
    [[ "$feat_count" -gt 0 ]] && echo "    - Features: $feat_count"
    [[ "$fix_count" -gt 0 ]] && echo "    - Fixes: $fix_count"
    [[ "$docs_count" -gt 0 ]] && echo "    - Docs: $docs_count"
    [[ "$other_count" -gt 0 ]] && echo "    - Other: $other_count"
    
    # Warning if only docs/chore commits
    if [[ "$feat_count" -eq 0 && "$fix_count" -eq 0 ]]; then
        log_warning "Only non-feature/non-fix commits since last release"
        echo "  This release contains only documentation or maintenance changes."
        echo "  Consider whether a version bump is necessary."
        echo ""
        if ! confirm "Continue with release?"; then
            log_error "Release cancelled by user"
        fi
    fi
    
    log_success "Commits validated ($commit_count total)"
}

#
# validate_dev_container - Ensure dev container is running
#
validate_dev_container() {
    log_info "${EMOJI_CHECK} Validating dev container..."
    
    # Get project-specific container service name
    local service_suffix=""
    if [[ -v PROJECT_MAIN_CONTAINER["$PROJECT_NAME"] ]]; then
        service_suffix="${PROJECT_MAIN_CONTAINER["$PROJECT_NAME"]}"
    fi
    local container_name
    
    if [[ -z "$service_suffix" ]]; then
        # No suffix (e.g., terminal)
        container_name="dashtam-${PROJECT_NAME}-dev"
    else
        # With suffix (e.g., api-dev-app, jobs-dev-worker)
        container_name="dashtam-${PROJECT_NAME}-dev-${service_suffix}"
    fi
    
    # Check if container is running
    if ! is_container_running "$container_name"; then
        log_warning "Dev container not running: $container_name"
        echo "  Attempting to start dev environment..."
        echo ""
        
        cd "$PROJECT_PATH" || exit 1
        
        # Try to start dev environment
        if ! make dev-up; then
            log_error "Failed to start dev environment\n  Try manually: cd $PROJECT_PATH && make dev-up"
        fi
        
        # Wait a moment for container to be ready
        sleep 2
        
        # Verify container is now running
        if ! is_container_running "$container_name"; then
            log_error "Container started but not running: $container_name\n  Check logs: cd $PROJECT_PATH && make dev-logs"
        fi
        
        log_success "Dev environment started successfully"
    else
        log_success "Dev container running: $container_name"
    fi
}

# =============================================================================
# RELEASE ACTIONS
# =============================================================================

#
# update_version - Update version in pyproject.toml
#
update_version() {
    log_info "📝 Updating pyproject.toml version..."
    
    local pyproject="$PROJECT_PATH/pyproject.toml"
    
    if [[ "$ARG_DRY_RUN" == "1" ]]; then
        # Show exact line that would be changed
        local current_line
        local new_line
        current_line=$(grep -n '^version = ' "$pyproject" | head -1)
        local line_num=$(echo "$current_line" | cut -d: -f1)
        
        echo ""
        log_info "[DRY RUN] File: pyproject.toml (line $line_num)"
        echo -e "  ${COLOR_RED}- version = \"$CURRENT_VERSION\"${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}+ version = \"$NEW_VERSION\"${COLOR_RESET}"
        echo ""
        return 0
    fi
    
    cd "$PROJECT_PATH" || exit 1
    
    # Update version using sed (portable across macOS and Linux)
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS requires empty string for -i
        sed -i '' "s/^version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" "$pyproject"
    else
        # Linux
        sed -i "s/^version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" "$pyproject"
    fi
    
    # Verify update
    local updated_version
    updated_version=$(grep '^version = ' "$pyproject" | cut -d'"' -f2)
    
    if [[ "$updated_version" != "$NEW_VERSION" ]]; then
        echo ""
        log_error "Failed to update version in pyproject.toml

Expected: version = \"$NEW_VERSION\"
Actual:   version = \"$updated_version\"

Possible causes:
  - pyproject.toml format is non-standard
  - Version string not found or formatted differently

To investigate:
  grep '^version' $pyproject

The script will revert all changes automatically."
    fi
    
    log_success "Version updated: $CURRENT_VERSION → $NEW_VERSION"
}

#
# run_uv_lock - Run uv lock in dev container and validate
#
run_uv_lock() {
    log_info "🔒 Running uv lock in dev container..."
    
    # Get project-specific container service name
    local service_suffix=""
    if [[ -v PROJECT_MAIN_CONTAINER["$PROJECT_NAME"] ]]; then
        service_suffix="${PROJECT_MAIN_CONTAINER["$PROJECT_NAME"]}"
    fi
    local container_name
    
    if [[ -z "$service_suffix" ]]; then
        # No suffix (e.g., terminal)
        container_name="dashtam-${PROJECT_NAME}-dev"
    else
        # With suffix (e.g., api-dev-app, jobs-dev-worker)
        container_name="dashtam-${PROJECT_NAME}-dev-${service_suffix}"
    fi
    
    if [[ "$ARG_DRY_RUN" == "1" ]]; then
        echo ""
        log_info "[DRY RUN] Running: docker exec $container_name uv lock"
        echo ""
        
        # Check if uv supports --dry-run (it does as of v0.5.0+)
        if docker exec "$container_name" bash -c "cd /app && uv lock --help" 2>/dev/null | grep -q "\--dry-run"; then
            # Run with --dry-run and capture output
            if docker exec "$container_name" bash -c "cd /app && uv lock --dry-run" 2>&1; then
                echo ""
                log_info "${COLOR_GREEN}✓${COLOR_RESET} uv lock --dry-run succeeded (no errors)"
            else
                echo ""
                log_warning "uv lock --dry-run found potential issues (see above)"
            fi
        else
            # Fallback: just show command
            log_info "  Command: docker exec $container_name bash -c 'cd /app && uv lock'"
            log_info "  Note: uv --dry-run not available, showing command only"
        fi
        echo ""
        return 0
    fi
    
    cd "$PROJECT_PATH" || exit 1
    
    # Run uv lock
    if ! docker exec "$container_name" bash -c "cd /app && uv lock"; then
        echo ""
        log_error "Failed to run uv lock in container: $container_name

Possible causes:
  - Container doesn't have /app directory mounted
  - uv not installed in container
  - Dependency resolution conflict
  - Network issues downloading packages

To investigate:
  cd $PROJECT_PATH
  make dev-shell
  # Then inside container:
  cd /app && uv lock --verbose

The script will revert all changes automatically."
    fi
    
    # Validate lock file was updated
    if git diff --quiet uv.lock; then
        log_warning "Lock file unchanged (may indicate issue)"
    else
        log_success "Lock file updated"
    fi
    
    # Validate lock file is parsable
    if ! docker exec "$container_name" bash -c "cd /app && uv lock --check" > /dev/null 2>&1; then
        echo ""
        log_error "Lock file validation failed

The generated uv.lock file is not parsable.

To investigate:
  cd $PROJECT_PATH
  docker exec $container_name uv lock --check

To fix:
  # Review lock file for errors
  cat uv.lock | head -50

The script will revert all changes automatically."
    fi
    
    log_success "uv lock completed successfully"
}

#
# generate_changelog - Generate CHANGELOG entry from milestone issues
#
generate_changelog() {
    log_info "📋 Generating CHANGELOG entry..."
    
    cd "$PROJECT_PATH" || exit 1
    
    local changelog="CHANGELOG.md"
    local repo_name
    repo_name=$(basename "$PROJECT_PATH")
    
    # Create CHANGELOG if it doesn't exist
    if [[ ! -f "$changelog" ]]; then
        echo "# Changelog" > "$changelog"
        echo "" >> "$changelog"
        echo "All notable changes to this project will be documented in this file." >> "$changelog"
        echo "" >> "$changelog"
    fi
    
    # Generate entry header
    local entry_date
    entry_date=$(date '+%Y-%m-%d')
    local entry_header="\n## [${NEW_VERSION}] - ${entry_date}\n"
    
    # Fetch issues from milestone (if specified) or recent closed issues
    local issues_json
    if [[ -n "$ARG_MILESTONE" ]]; then
        issues_json=$(gh issue list \
            --repo "faiyaz7283/dashtam-$repo_name" \
            --milestone "$ARG_MILESTONE" \
            --state closed \
            --limit 100 \
            --json number,title,labels \
            --jq '.[] | {number, title, type: .labels[].name}')
    else
        # Get issues closed in last 30 days
        issues_json=$(gh issue list \
            --repo "faiyaz7283/dashtam-$repo_name" \
            --state closed \
            --limit 50 \
            --json number,title,labels,closedAt \
            --jq '.[] | select(.closedAt >= (now - 2592000)) | {number, title, type: .labels[].name}')
    fi
    
    # Group issues by type
    local features=$(echo "$issues_json" | jq -r 'select(.type == "enhancement") | "- \(.title) (#\(.number))"' | sort)
    local fixes=$(echo "$issues_json" | jq -r 'select(.type == "bug") | "- \(.title) (#\(.number))"' | sort)
    local docs=$(echo "$issues_json" | jq -r 'select(.type == "documentation") | "- \(.title) (#\(.number))"' | sort)
    
    # Build CHANGELOG entry
    local entry="$entry_header"
    
    if [[ -n "$features" ]]; then
        entry+="\n### Features\n$features\n"
    fi
    
    if [[ -n "$fixes" ]]; then
        entry+="\n### Bug Fixes\n$fixes\n"
    fi
    
    if [[ -n "$docs" ]]; then
        entry+="\n### Documentation\n$docs\n"
    fi
    
    # If no issues found, add placeholder
    if [[ -z "$features" && -z "$fixes" && -z "$docs" ]]; then
        entry+="\n- Version bump\n"
    fi
    
    # Display in verbose mode or dry-run
    if [[ "$ARG_VERBOSE" == "1" || "$ARG_DRY_RUN" == "1" ]]; then
        echo ""
        echo -e "${COLOR_CYAN}────────────────────────────────────────────────────────────${COLOR_RESET}"
        echo -e "${COLOR_BOLD}Generated CHANGELOG Entry:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}────────────────────────────────────────────────────────────${COLOR_RESET}"
        echo -e "$entry"
        echo -e "${COLOR_CYAN}────────────────────────────────────────────────────────────${COLOR_RESET}"
        echo ""
    fi
    
    # Dry-run: skip file write
    if [[ "$ARG_DRY_RUN" == "1" ]]; then
        log_success "CHANGELOG content generated (not written)"
        return 0
    fi
    
    # Real run: Insert entry after header (line 4)
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "4a\\
$entry" "$changelog"
    else
        sed -i "4a\\$entry" "$changelog"
    fi
    
    # Validate markdown linting
    log_info "Validating CHANGELOG.md markdown..."
    if ! docker run --rm -v "$PROJECT_PATH:/workspace:ro" -w /workspace \
        node:24-alpine npx markdownlint-cli2 "CHANGELOG.md" > /dev/null 2>&1; then
        log_warning "CHANGELOG.md has markdown linting violations"
        log_info "Run: make lint-md FILE=CHANGELOG.md to see violations"
    fi
    
    log_success "CHANGELOG entry generated"
}

#
# create_release_branch - Create and checkout release branch
#
create_release_branch() {
    RELEASE_BRANCH="release/v$NEW_VERSION"
    
    log_info "🌿 Creating release branch: $RELEASE_BRANCH"
    
    if [[ "$ARG_DRY_RUN" == "1" ]]; then
        echo ""
        log_info "[DRY RUN] Command: git checkout -b $RELEASE_BRANCH"
        echo ""
        return 0
    fi
    
    cd "$PROJECT_PATH" || exit 1
    
    # Create and checkout branch
    git checkout -b "$RELEASE_BRANCH"
    
    # Add to cleanup actions
    CLEANUP_ACTIONS+=(
        "git checkout development"
        "git branch -D $RELEASE_BRANCH 2>/dev/null || true"
        "git push origin --delete $RELEASE_BRANCH 2>/dev/null || true"
    )
    
    log_success "Created branch: $RELEASE_BRANCH"
}

#
# commit_changes - Commit version bump and CHANGELOG
#
commit_changes() {
    log_info "💾 Committing changes..."
    
    if [[ "$ARG_DRY_RUN" == "1" ]]; then
        echo ""
        log_info "[DRY RUN] Commands:"
        echo "  git add pyproject.toml uv.lock CHANGELOG.md"
        echo "  git commit -m \"chore(release): bump version to $NEW_VERSION\""
        echo ""
        return 0
    fi
    
    cd "$PROJECT_PATH" || exit 1
    
    # Stage files
    git add pyproject.toml uv.lock CHANGELOG.md
    
    # Commit with conventional commit format
    git commit -m "chore(release): bump version to $NEW_VERSION

- Update pyproject.toml version
- Update uv.lock
- Add CHANGELOG entry for v$NEW_VERSION

Co-Authored-By: Warp <agent@warp.dev>"
    
    log_success "Changes committed"
}

#
# push_branch - Push release branch to remote
#
push_branch() {
    log_info "⬆️  Pushing branch to remote..."
    
    if [[ "$ARG_DRY_RUN" == "1" ]]; then
        echo ""
        log_info "[DRY RUN] Command: git push origin $RELEASE_BRANCH"
        echo ""
        return 0
    fi
    
    cd "$PROJECT_PATH" || exit 1
    
    git push origin "$RELEASE_BRANCH"
    
    log_success "Branch pushed: $RELEASE_BRANCH"
}

#
# create_pr - Create PR to development with automated-release label
#
create_pr() {
    log_info "📬 Creating PR to development..."
    
    cd "$PROJECT_PATH" || exit 1
    
    local repo_name
    repo_name=$(basename "$PROJECT_PATH")
    
    if [[ "$ARG_DRY_RUN" == "1" ]]; then
        echo ""
        log_info "[DRY RUN] Commands:"
        echo "  gh pr create \\"
        echo "    --repo faiyaz7283/dashtam-$repo_name \\"
        echo "    --base development \\"
        echo "    --head $RELEASE_BRANCH \\"
        echo "    --title \"chore(release): v$NEW_VERSION\" \\"
        echo "    --body \"...\" \\"
        echo "    --label $RELEASE_LABEL"
        echo ""
        return 0
    fi
    
    # Get CHANGELOG entry for PR body
    local changelog_entry
    changelog_entry=$(awk '/^## \['"$NEW_VERSION"'\]/,/^## \[/{if(/^## \[/ && !/^## \['"$NEW_VERSION"'\]/) exit; print}' CHANGELOG.md)
    
    # Create PR
    local pr_url
    pr_url=$(gh pr create \
        --repo "faiyaz7283/dashtam-$repo_name" \
        --base development \
        --head "$RELEASE_BRANCH" \
        --title "chore(release): v$NEW_VERSION" \
        --body "## Release v$NEW_VERSION

Automated release PR created by release automation script.

### Changes
$changelog_entry

---

**Next Steps**:
1. ✅ CI will run automatically
2. ⏳ PR will be auto-merged when CI passes (via GitHub Actions)
3. ⏳ GitHub Actions will create PR to main
4. ⏳ After main merge, GitHub Actions will tag and create GitHub Release

**Note**: This PR is labeled with \`$RELEASE_LABEL\` for automation.")
    
    # Extract PR number from URL
    PR_NUMBER=$(basename "$pr_url")
    
    # Add automated-release label
    gh pr edit "$PR_NUMBER" \
        --repo "faiyaz7283/dashtam-$repo_name" \
        --add-label "$RELEASE_LABEL"
    
    log_success "PR created: $pr_url"
    log_success "PR number: #$PR_NUMBER"
    log_success "Label added: $RELEASE_LABEL"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

main() {
    # Parse arguments
    parse_args "$@"
    
    # Show banner
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ${EMOJI_ROCKET} Dashtam Release Automation"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ "$ARG_DRY_RUN" == "1" ]]; then
        log_warning "DRY RUN MODE - No changes will be made"
        echo ""
    fi
    
    # Step 1: Detect project
    detect_project
    
    # Step 2: Validate prerequisites
    validate_prerequisites
    
    # Step 3: Validate git state
    validate_git_state
    
    # Step 4: Get current version
    get_current_version
    
    # Step 5: Determine new version
    determine_new_version
    
    # Step 6: Validate version
    validate_version
    
    # Step 7: Validate commits since last release
    validate_commits_since_last_release
    
    # Step 8: Validate milestone (if specified)
    validate_milestone
    
    # Step 9: Validate dev container
    validate_dev_container
    
    echo ""
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "Pre-flight checks complete ✅"
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Show release summary and confirm
    echo "📋 Release Summary:"
    echo "  Project:       $PROJECT_NAME"
    echo "  Current:       v$CURRENT_VERSION"
    echo "  New:           v$NEW_VERSION"
    if [[ -n "$ARG_MILESTONE" ]]; then
        echo "  Milestone:     $ARG_MILESTONE"
    fi
    echo "  Branch:        $RELEASE_BRANCH"
    echo ""
    
    if ! confirm "Proceed with release?"; then
        log_error "Release cancelled by user"
    fi
    
    # Mark that script has started execution (past validation)
    # This tells cleanup to revert script-modified files on error
    export SCRIPT_STARTED=1
    
    echo ""
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "Starting release process..."
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Step 10: Update version
    update_version
    
    # Step 11: Run uv lock
    run_uv_lock
    
    # Step 12: Generate CHANGELOG
    generate_changelog
    
    # Step 13: Create release branch
    create_release_branch
    
    # Step 14: Commit changes
    commit_changes
    
    # Step 15: Push branch
    push_branch
    
    # Step 16: Create PR
    create_pr
    
    echo ""
    log_info "═══════════════════════════════════════════════════════════════"
    log_success "🎉 Release preparation complete!"
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ "$ARG_DRY_RUN" != "1" ]]; then
        echo "✅ PR created and labeled with '$RELEASE_LABEL'"
        echo "✅ CI will run automatically"
        echo ""
        echo "⏳ Next Steps (Automated via GitHub Actions):"
        echo "  1. Wait for CI to pass"
        echo "  2. GitHub Actions will auto-merge PR to development"
        echo "  3. GitHub Actions will create PR to main"
        echo "  4. After main merge, GitHub Actions will:"
        echo "     - Tag release v$NEW_VERSION"
        echo "     - Create GitHub Release"
        echo "     - Sync main → development"
        echo ""
        echo "🔗 View PR: $(gh pr view "$PR_NUMBER" --repo "faiyaz7283/dashtam-$(basename "$PROJECT_PATH")" --json url --jq '.url')"
    else
        log_warning "DRY RUN MODE - No actual changes were made"
    fi
}

# Set up error handling
trap cleanup_on_error EXIT

# Run main function
main "$@"
