#!/usr/bin/env bash
#
# common.sh - Shared Functions Library for Dashtam Automation Scripts
#
# Purpose:
#   Provides reusable functions for logging, error handling, validation,
#   and common operations across all Dashtam automation scripts.
#
# Usage:
#   Source this file at the beginning of your script:
#   
#   #!/usr/bin/env bash
#   set -euo pipefail
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/common.sh"
#
# Functions:
#   Logging:
#     - log_info      Info messages (blue)
#     - log_success   Success messages (green)
#     - log_warning   Warning messages (yellow)
#     - log_error     Error messages (red, exits with code 1)
#
#   Validation:
#     - check_dependency     Check if command exists
#     - detect_projects      Find all submodule projects
#     - is_container_running Check if Docker container is running
#     - validate_semver      Validate semantic version format
#     - version_compare      Compare two semver versions
#
#   Docker:
#     - exec_in_container    Execute command in Docker container
#
#   Utilities:
#     - confirm              Prompt user for yes/no confirmation
#     - cleanup_on_error     Cleanup handler for trap EXIT
#
# Author: Dashtam Team
# Last Updated: 2026-01-22

# Prevent multiple sourcing
if [[ "${COMMON_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
COMMON_SH_LOADED=true

# =============================================================================
# CONSTANTS
# =============================================================================

# Color codes for terminal output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'

# Emoji for visual clarity
readonly EMOJI_SUCCESS="✅"
readonly EMOJI_ERROR="❌"
readonly EMOJI_WARNING="⚠️"
readonly EMOJI_INFO="ℹ️"
readonly EMOJI_ROCKET="🚀"
readonly EMOJI_CHECK="🔍"

# Dashtam project paths
readonly DASHTAM_ROOT="${DASHTAM_ROOT:-$HOME/dashtam}"
readonly DASHTAM_PROJECTS=("api" "terminal" "jobs")

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

#
# log_info - Print informational message
#
# Usage:
#   log_info "Starting process..."
#   log_info "Found 5 files"
#
# Arguments:
#   $1 - Message to display
#
# Output:
#   Blue colored message with info emoji and timestamp
#
log_info() {
    local message="$1"
    echo -e "${COLOR_BLUE}${EMOJI_INFO} $(date '+%H:%M:%S')${COLOR_RESET} ${message}"
}

#
# log_success - Print success message
#
# Usage:
#   log_success "Tests passed!"
#   log_success "Release complete"
#
# Arguments:
#   $1 - Message to display
#
# Output:
#   Green colored message with success emoji
#
log_success() {
    local message="$1"
    echo -e "${COLOR_GREEN}${EMOJI_SUCCESS}${COLOR_RESET} ${message}"
}

#
# log_warning - Print warning message
#
# Usage:
#   log_warning "CI not passing on development branch"
#   log_warning "Lock file unchanged"
#
# Arguments:
#   $1 - Message to display
#
# Output:
#   Yellow colored message with warning emoji
#
log_warning() {
    local message="$1"
    echo -e "${COLOR_YELLOW}${EMOJI_WARNING}${COLOR_RESET} ${message}"
}

#
# log_error - Print error message and exit
#
# Usage:
#   log_error "Failed to connect to database"
#   log_error "Invalid version format"
#
# Arguments:
#   $1 - Error message to display
#   $2 - Exit code (optional, default: 1)
#
# Output:
#   Red colored message with error emoji
#   Exits script with specified code
#
log_error() {
    local message="$1"
    local exit_code="${2:-1}"
    echo -e "${COLOR_RED}${EMOJI_ERROR}${COLOR_RESET} ${message}" >&2
    exit "$exit_code"
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

#
# check_dependency - Verify required command exists
#
# Usage:
#   check_dependency "docker" "Install Docker: https://docs.docker.com/get-docker/"
#   check_dependency "gh" "Install GitHub CLI: https://cli.github.com/"
#
# Arguments:
#   $1 - Command name to check
#   $2 - Help message if command not found (optional)
#
# Returns:
#   0 if command exists, exits with error if not found
#
check_dependency() {
    local cmd="$1"
    local help_message="${2:-}"
    
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd\n${help_message}"
    fi
}

#
# detect_projects - Find all Dashtam submodule projects
#
# Usage:
#   PROJECTS=$(detect_projects)
#   for project in $PROJECTS; do
#       echo "Found: $project"
#   done
#
# Arguments:
#   None
#
# Output:
#   Space-separated list of project names (api terminal jobs)
#
# Returns:
#   0 if projects found, 1 if DASHTAM_ROOT invalid
#
detect_projects() {
    if [[ ! -d "$DASHTAM_ROOT" ]]; then
        log_error "Dashtam root not found: $DASHTAM_ROOT"
        return 1
    fi
    
    local projects=()
    for project in "${DASHTAM_PROJECTS[@]}"; do
        if [[ -d "$DASHTAM_ROOT/$project" ]]; then
            projects+=("$project")
        fi
    done
    
    echo "${projects[@]}"
}

#
# is_container_running - Check if Docker container is running
#
# Usage:
#   if is_container_running "dashtam-dev-app"; then
#       echo "Container is running"
#   fi
#
# Arguments:
#   $1 - Container name or ID
#
# Returns:
#   0 if container is running, 1 otherwise
#
is_container_running() {
    local container="$1"
    docker ps --format '{{.Names}}' | grep -q "^${container}$"
}

#
# validate_semver - Validate semantic version format
#
# Usage:
#   if validate_semver "1.2.3"; then
#       echo "Valid version"
#   fi
#
# Arguments:
#   $1 - Version string to validate
#
# Returns:
#   0 if valid semver (X.Y.Z), 1 otherwise
#
validate_semver() {
    local version="$1"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

#
# version_compare - Compare two semantic versions
#
# Usage:
#   if version_compare "1.2.3" "1.2.0"; then
#       echo "1.2.3 is greater than 1.2.0"
#   fi
#
# Arguments:
#   $1 - First version (X.Y.Z)
#   $2 - Second version (X.Y.Z)
#
# Returns:
#   0 if v1 > v2, 1 otherwise
#
version_compare() {
    local v1="$1"
    local v2="$2"
    
    # Split versions into components
    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"
    
    # Compare major, minor, patch
    for i in 0 1 2; do
        local part1="${v1_parts[$i]:-0}"
        local part2="${v2_parts[$i]:-0}"
        
        if (( part1 > part2 )); then
            return 0
        elif (( part1 < part2 )); then
            return 1
        fi
    done
    
    # Versions are equal
    return 1
}

#
# validate_version_increment - Validate version is a valid semver increment
#
# Ensures new version is an organic increment from current version.
# Valid increments:
#   - Major: X.0.0 (X incremented by 1+)
#   - Minor: x.Y.0 (Y incremented by 1+, X unchanged)
#   - Patch: x.y.Z (Z incremented by 1+, X.Y unchanged)
#
# Invalid examples (current 1.9.2):
#   - 1.21.2 (minor jumped from 9 to 21, not organic)
#   - 3.9.2  (major jumped from 1 to 3 with minor unchanged)
#   - 1.9.5  (patch jumped by 3 instead of 1-2)
#
# Usage:
#   if validate_version_increment "1.10.0" "1.9.2"; then
#       echo "Valid minor increment"
#   fi
#
# Arguments:
#   $1 - New version (X.Y.Z)
#   $2 - Current version (X.Y.Z)
#
# Output:
#   Error message to stderr if invalid
#
# Returns:
#   0 if valid increment, 1 otherwise
#
validate_version_increment() {
    local new_version="$1"
    local current_version="$2"
    
    # Split versions
    IFS='.' read -ra new_parts <<< "$new_version"
    IFS='.' read -ra cur_parts <<< "$current_version"
    
    local new_major="${new_parts[0]}"
    local new_minor="${new_parts[1]}"
    local new_patch="${new_parts[2]}"
    
    local cur_major="${cur_parts[0]}"
    local cur_minor="${cur_parts[1]}"
    local cur_patch="${cur_parts[2]}"
    
    # Case 1: Major version bump
    if (( new_major > cur_major )); then
        # Minor and patch must be 0
        if [[ "$new_minor" != "0" || "$new_patch" != "0" ]]; then
            echo "Major version bump must reset minor and patch to 0" >&2
            echo "  Current: $current_version" >&2
            echo "  New:     $new_version" >&2
            echo "  Valid:   $((cur_major + 1)).0.0 (or higher major)" >&2
            return 1
        fi
        # Valid major bump
        return 0
    fi
    
    # Case 2: Minor version bump (major unchanged)
    if (( new_major == cur_major && new_minor > cur_minor )); then
        # Patch must be 0
        if [[ "$new_patch" != "0" ]]; then
            echo "Minor version bump must reset patch to 0" >&2
            echo "  Current: $current_version" >&2
            echo "  New:     $new_version" >&2
            echo "  Valid:   $cur_major.$((cur_minor + 1)).0 (or higher minor)" >&2
            return 1
        fi
        # Valid minor bump
        return 0
    fi
    
    # Case 3: Patch version bump (major and minor unchanged)
    if (( new_major == cur_major && new_minor == cur_minor && new_patch > cur_patch )); then
        # Valid patch bump
        return 0
    fi
    
    # Case 4: Invalid - version did not increase or violated rules
    if (( new_major < cur_major )); then
        echo "Major version cannot decrease" >&2
    elif (( new_major == cur_major && new_minor < cur_minor )); then
        echo "Minor version cannot decrease when major is unchanged" >&2
    elif (( new_major == cur_major && new_minor == cur_minor && new_patch <= cur_patch )); then
        echo "Patch version must increase when major.minor are unchanged" >&2
    else
        # This shouldn't happen, but catch any edge cases
        echo "Invalid version increment" >&2
    fi
    
    echo "  Current: $current_version" >&2
    echo "  New:     $new_version" >&2
    echo "  Valid increments:" >&2
    echo "    - Major: $((cur_major + 1)).0.0" >&2
    echo "    - Minor: $cur_major.$((cur_minor + 1)).0" >&2
    echo "    - Patch: $cur_major.$cur_minor.$((cur_patch + 1))" >&2
    
    return 1
}

# =============================================================================
# DOCKER FUNCTIONS
# =============================================================================

#
# exec_in_container - Execute command inside Docker container
#
# Usage:
#   exec_in_container "dashtam-dev-app" "uv lock"
#   output=$(exec_in_container "dashtam-dev-app" "cat pyproject.toml")
#
# Arguments:
#   $1 - Container name
#   $2 - Command to execute
#
# Output:
#   Command output from container
#
# Returns:
#   Exit code from command execution
#
exec_in_container() {
    local container="$1"
    local cmd="$2"
    
    if ! is_container_running "$container"; then
        log_error "Container not running: $container"
        return 1
    fi
    
    docker exec "$container" bash -c "$cmd"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

#
# confirm - Prompt user for yes/no confirmation
#
# Usage:
#   if confirm "Proceed with release?"; then
#       echo "User confirmed"
#   else
#       echo "User cancelled"
#   fi
#
#   # Skip confirmation with YES=1 environment variable
#   YES=1 ./script.sh  # Will auto-confirm
#
# Arguments:
#   $1 - Prompt message
#   $2 - Default response (optional: "yes" or "no", default: "no")
#
# Returns:
#   0 if user confirms (yes), 1 if user cancels (no)
#
confirm() {
    local prompt="$1"
    local default="${2:-no}"
    
    # Skip confirmation if YES environment variable is set
    if [[ "${YES:-0}" == "1" ]]; then
        log_info "Auto-confirmed (YES=1): $prompt"
        return 0
    fi
    
    # Build prompt with default indicator
    local prompt_suffix
    if [[ "$default" == "yes" ]]; then
        prompt_suffix="(yes/no) [yes]: "
    else
        prompt_suffix="(yes/no) [no]: "
    fi
    
    # Prompt user
    echo -n "${prompt} ${prompt_suffix}"
    read -r response
    
    # Use default if no response
    response="${response:-$default}"
    
    # Check response
    case "$response" in
        yes|y|Y|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

#
# cleanup_on_error - Cleanup handler for trap EXIT
#
# Usage:
#   trap cleanup_on_error EXIT
#   
#   # Your script logic here...
#   # If script exits with error, cleanup_on_error will run
#
# Arguments:
#   None (reads $? for exit code)
#
# Global Variables:
#   CLEANUP_ACTIONS - Array of cleanup commands to execute
#
# Example:
#   CLEANUP_ACTIONS=(
#       "git checkout development"
#       "git branch -D release/v1.2.0"
#   )
#   trap cleanup_on_error EXIT
#
cleanup_on_error() {
    local exit_code=$?
    
    # Only cleanup on error
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        log_warning "Script failed with exit code $exit_code"
        
        # NEVER revert files in dry-run mode
        if [[ "${DRY_RUN:-0}" == "1" ]]; then
            log_info "Dry-run mode - no cleanup needed"
            return 0
        fi
        
        # Execute cleanup actions if defined
        if [[ -n "${CLEANUP_ACTIONS+x}" ]] && [[ ${#CLEANUP_ACTIONS[@]} -gt 0 ]]; then
            log_info "Running cleanup actions..."
            for action in "${CLEANUP_ACTIONS[@]}"; do
                echo "  → $action"
                eval "$action" 2>/dev/null || true
            done
            log_success "Cleanup complete"
        else
            # No cleanup actions means we failed early (before Step 13: create branch)
            # This could be:
            #   1. Pre-existing uncommitted changes (Step 3 validation)
            #   2. Changes made by script (Steps 10-12) that need rollback
            # 
            # CRITICAL: Only revert if files were modified AFTER script started
            # We detect this by checking if SCRIPT_STARTED marker was set
            
            if [[ "${SCRIPT_STARTED:-0}" == "1" ]]; then
                # Script started executing (past all pre-flight checks)
                # Revert ONLY the files modified by the script
                log_info "Reverting script-modified files..."
                
                # Change to project directory (required for git operations)
                if [[ -n "${PROJECT_PATH:-}" ]] && [[ -d "$PROJECT_PATH" ]]; then
                    cd "$PROJECT_PATH" || true
                fi
                
                # Release script only modifies these 3 files
                local files_to_revert=("pyproject.toml" "uv.lock" "CHANGELOG.md")
                local reverted_count=0
                
                for file in "${files_to_revert[@]}"; do
                    if [[ -f "$file" ]] && ! git diff --quiet "$file" 2>/dev/null; then
                        echo "  → git checkout -- $file"
                        git checkout -- "$file" 2>/dev/null || true
                        (( reverted_count += 1 ))
                    fi
                done
                
                if [[ $reverted_count -gt 0 ]]; then
                    log_success "Reverted $reverted_count file(s)"
                else
                    log_info "No script-modified files to revert"
                fi
            else
                # Script failed during pre-flight checks
                # DO NOT touch any files - they existed before script ran
                log_info "Failed during validation - no files modified by script"
            fi
        fi
    fi
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Check if running in bash (required for associative arrays and other features)
if [[ -z "${BASH_VERSION:-}" ]]; then
    echo "Error: This script requires bash" >&2
    exit 1
fi

# Validate DASHTAM_ROOT exists
if [[ ! -d "$DASHTAM_ROOT" ]]; then
    echo "Warning: DASHTAM_ROOT not found: $DASHTAM_ROOT" >&2
    echo "  Set DASHTAM_ROOT environment variable or ensure ~/dashtam exists" >&2
fi
