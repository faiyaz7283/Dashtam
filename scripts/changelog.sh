#!/opt/homebrew/bin/bash
#
# changelog.sh - Standalone CHANGELOG Generation Script
#
# Purpose:
#   Generates CHANGELOG entries for Dashtam projects. Can be used standalone
#   for testing/manual generation, or called by release.sh during releases.
#
# Usage:
#   # Preview auto-generated entry (outputs to stdout)
#   ./scripts/changelog.sh --project api --version 1.9.6
#
#   # Preview with milestone
#   ./scripts/changelog.sh --project api --version 1.9.6 --milestone "v1.9.6"
#
#   # Write to CHANGELOG.md (default behavior)
#   ./scripts/changelog.sh --project api --version 1.9.6
#
#   # Dry-run (preview only, no file changes)
#   ./scripts/changelog.sh --project api --version 1.9.6 --dry-run
#
#   # Custom content from file
#   ./scripts/changelog.sh --project api --version 1.9.6 --changelog-file notes.md
#
#   # Custom content inline (heredoc supported)
#   ./scripts/changelog.sh --project api --version 1.9.6 --changelog "### Added
#   - Feature X (#123)"
#
#   # Open editor to write content
#   ./scripts/changelog.sh --project api --version 1.9.6 --changelog-editor
#
#   # Write and validate markdown
#   ./scripts/changelog.sh --project api --version 1.9.6 --lint
#
# Flags:
#   --project, -p       Project name (api, terminal, jobs) - required
#   --version, -v       Version number (X.Y.Z) - required
#   --milestone, -m     GitHub milestone for issue fetching (optional)
#   --changelog, -c     Custom CHANGELOG content (inline, heredoc supported)
#   --changelog-file    Path to file containing CHANGELOG content
#   --changelog-editor  Open $EDITOR to write CHANGELOG content
#   --dry-run           Preview only, don't write to CHANGELOG.md
#   --lint              Validate markdown after writing
#   --verbose           Show detailed output
#   --help, -h          Show this help message
#
# Content Sources (priority order):
#   1. --changelog "content"   : Inline content
#   2. --changelog-file path   : Read from file
#   3. --changelog-editor      : Open $EDITOR
#   4. Auto-generate (hybrid)  : Issues + commits (default)
#
# Hybrid Auto-Generation:
#   - Fetches closed issues from milestone (grouped by label)
#   - For each issue, finds related commits (by #N reference)
#   - Formats with issue as header, commits as sub-bullets
#
# Output Format (Keep a Changelog standard):
#   ## [X.Y.Z] - YYYY-MM-DD
#
#   ### Added
#
#   - **Issue title** (#123)
#     - Related commit message
#     - Another commit
#
#   ### Fixed
#
#   - **Bug fix** (#124)
#
# Author: Dashtam Team
# Last Updated: 2026-01-24

set -euo pipefail

# =============================================================================
# SETUP
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================

ARG_PROJECT=""
ARG_VERSION=""
ARG_MILESTONE=""
ARG_CHANGELOG=""
ARG_CHANGELOG_FILE=""
ARG_CHANGELOG_EDITOR=0
ARG_DRY_RUN=0
ARG_LINT=0
ARG_VERBOSE=0

PROJECT_PATH=""

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

show_help() {
    cat << 'EOF'
CHANGELOG Generation Script for Dashtam Projects

Usage:
  changelog.sh [OPTIONS]

Options:
  -p, --project PROJECT     Project name (api, terminal, jobs) [required]
  -v, --version VERSION     Version number (X.Y.Z format) [required]
  -m, --milestone NAME      GitHub milestone for issue fetching
  -c, --changelog TEXT      Custom CHANGELOG content (supports heredoc)
  --changelog-file FILE     Read CHANGELOG content from file
  --changelog-editor        Open $EDITOR to write CHANGELOG content
  --dry-run                 Preview only, don't write to CHANGELOG.md
  --lint                    Validate markdown after writing
  --verbose                 Show detailed output
  -h, --help                Show this help message

Content Sources (priority order):
  1. --changelog "content"   : Inline content
  2. --changelog-file path   : Read from file
  3. --changelog-editor      : Open $EDITOR
  4. Auto-generate (hybrid)  : Issues + commits (default)

Examples:
  # Preview auto-generated entry
  changelog.sh --project api --version 1.9.6

  # Write to CHANGELOG.md with milestone (default behavior)
  changelog.sh -p api -v 1.9.6 -m "v1.9.6"

  # Dry-run (preview only)
  changelog.sh -p api -v 1.9.6 --dry-run

  # Custom content from file
  changelog.sh -p api -v 1.9.6 --changelog-file notes.md

  # Inline content (heredoc style)
  changelog.sh -p api -v 1.9.6 --changelog "$(cat <<'NOTES'
  ### Added

  - **New feature** (#123)
    - Implementation detail

  ### Fixed

  - **Bug fix** (#124)
  NOTES
  )" --write

  # Open editor
  changelog.sh -p api -v 1.9.6 --changelog-editor

  # Write and validate
  changelog.sh -p api -v 1.9.6 --lint

  # Dry-run with lint check (preview validation)
  changelog.sh -p api -v 1.9.6 --dry-run --lint

EOF
}

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
            -c|--changelog)
                ARG_CHANGELOG="$2"
                shift 2
                ;;
            --changelog-file)
                ARG_CHANGELOG_FILE="$2"
                shift 2
                ;;
            --changelog-editor)
                ARG_CHANGELOG_EDITOR=1
                shift
                ;;
            --dry-run)
                ARG_DRY_RUN=1
                shift
                ;;
            --lint)
                ARG_LINT=1
                shift
                ;;
            --verbose)
                ARG_VERBOSE=1
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
    
    # Validate required arguments
    if [[ -z "$ARG_PROJECT" ]]; then
        log_error "Missing required argument: --project\nUse --help for usage information"
    fi
    
    if [[ -z "$ARG_VERSION" ]]; then
        log_error "Missing required argument: --version\nUse --help for usage information"
    fi
    
    # Validate project name
    case "$ARG_PROJECT" in
        api|terminal|jobs)
            PROJECT_PATH="$DASHTAM_ROOT/$ARG_PROJECT"
            ;;
        *)
            log_error "Invalid project: $ARG_PROJECT\nValid projects: api, terminal, jobs"
            ;;
    esac
    
    # Validate project path exists
    if [[ ! -d "$PROJECT_PATH" ]]; then
        log_error "Project directory not found: $PROJECT_PATH"
    fi
    
    # Validate version format
    if [[ ! "$ARG_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: $ARG_VERSION\nExpected: X.Y.Z (e.g., 1.9.6)"
    fi
    
    # Validate changelog options are mutually exclusive
    local changelog_opts=0
    [[ -n "$ARG_CHANGELOG" ]] && (( changelog_opts += 1 ))
    [[ -n "$ARG_CHANGELOG_FILE" ]] && (( changelog_opts += 1 ))
    [[ "$ARG_CHANGELOG_EDITOR" == "1" ]] && (( changelog_opts += 1 ))
    
    if [[ $changelog_opts -gt 1 ]]; then
        log_error "Only one changelog option allowed: --changelog, --changelog-file, or --changelog-editor"
    fi
    
    # Validate changelog file exists if specified
    if [[ -n "$ARG_CHANGELOG_FILE" && ! -f "$ARG_CHANGELOG_FILE" ]]; then
        log_error "Changelog file not found: $ARG_CHANGELOG_FILE"
    fi
    
}

# =============================================================================
# CHANGELOG GENERATION
# =============================================================================

#
# get_changelog_content - Get CHANGELOG content from custom source or auto-generate
#
# Returns content body (without version header) via stdout
#
get_changelog_content() {
    local content=""
    local source=""
    
    # Priority 1: Inline content
    if [[ -n "$ARG_CHANGELOG" ]]; then
        content="$ARG_CHANGELOG"
        source="inline (--changelog)"
    
    # Priority 2: File content
    elif [[ -n "$ARG_CHANGELOG_FILE" ]]; then
        content=$(cat "$ARG_CHANGELOG_FILE")
        source="file ($ARG_CHANGELOG_FILE)"
    
    # Priority 3: Editor
    elif [[ "$ARG_CHANGELOG_EDITOR" == "1" ]]; then
        local tmp_editor_file
        tmp_editor_file=$(mktemp /tmp/changelog-XXXXXX.md)
        
        # Pre-populate with template
        cat > "$tmp_editor_file" << EOF
# CHANGELOG Entry for v${ARG_VERSION}
# Lines starting with # will be removed
# Save and exit to continue, or leave empty to auto-generate

### Added

- 

### Changed

- 

### Fixed

- 

EOF
        
        # Open editor
        local editor="${EDITOR:-${VISUAL:-vi}}"
        "$editor" "$tmp_editor_file"
        
        # Read content, stripping comment lines
        content=$(grep -v '^#' "$tmp_editor_file" | sed '/^$/N;/^\n$/d')
        rm -f "$tmp_editor_file"
        
        # If empty after stripping, fall through to auto-generate
        if [[ -z "$(echo "$content" | tr -d '[:space:]')" ]]; then
            [[ "$ARG_VERBOSE" == "1" ]] && log_info "Editor content empty, falling back to auto-generate"
            content=""
        else
            source="editor"
        fi
    fi
    
    # Priority 4: Auto-generate using hybrid approach
    if [[ -z "$content" ]]; then
        source="auto-generated (hybrid: issues + commits)"
        content=$(generate_hybrid_content)
    fi
    
    [[ "$ARG_VERBOSE" == "1" ]] && log_info "Content source: $source" >&2
    
    echo "$content"
}

#
# generate_hybrid_content - Auto-generate CHANGELOG using issues + commits
#
# Hybrid approach:
#   - Fetches closed issues from milestone (grouped by label)
#   - For each issue, finds related commits (by #N reference)
#   - Formats with issue as header, commits as sub-bullets
#
generate_hybrid_content() {
    local repo_name="$ARG_PROJECT"
    local full_repo="faiyaz7283/dashtam-$repo_name"
    
    cd "$PROJECT_PATH" || exit 1
    
    # =========================================================================
    # Fetch closed issues
    # =========================================================================
    local issues_json
    if [[ -n "$ARG_MILESTONE" ]]; then
        issues_json=$(gh issue list \
            --repo "$full_repo" \
            --milestone "$ARG_MILESTONE" \
            --state closed \
            --limit 100 \
            --json number,title,labels 2>/dev/null || echo "[]")
    else
        # Get issues closed in last 30 days
        issues_json=$(gh issue list \
            --repo "$full_repo" \
            --state closed \
            --limit 50 \
            --json number,title,labels,closedAt 2>/dev/null | \
            jq '[.[] | select(.closedAt >= (now - 2592000 | todate))]' 2>/dev/null || echo "[]")
    fi
    
    # =========================================================================
    # Get commits since last tag
    # =========================================================================
    local last_tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    local commits_since_tag=""
    if [[ -n "$last_tag" ]]; then
        commits_since_tag=$(git log "${last_tag}..HEAD" --oneline 2>/dev/null || echo "")
    else
        # No tags yet, get recent commits
        commits_since_tag=$(git log -50 --oneline 2>/dev/null || echo "")
    fi
    
    [[ "$ARG_VERBOSE" == "1" ]] && {
        log_info "Last tag: ${last_tag:-'none'}" >&2
        log_info "Commits since tag: $(echo "$commits_since_tag" | wc -l | tr -d ' ')" >&2
        log_info "Issues found: $(echo "$issues_json" | jq 'length' 2>/dev/null || echo 0)" >&2
    }
    
    # =========================================================================
    # Group issues by type and build entry
    # =========================================================================
    local entry_body=""
    
    # Process each category
    local categories=(
        "enhancement:### Added"
        "bug:### Fixed"
        "documentation:### Documentation"
        "security:### Security"
        "breaking:### Breaking Changes"
    )
    
    for cat_pair in "${categories[@]}"; do
        local label="${cat_pair%%:*}"
        local header="${cat_pair#*:}"
        
        # Get issues with this label
        local issues_with_label
        issues_with_label=$(echo "$issues_json" | jq -r \
            --arg label "$label" \
            '.[] | select(.labels[].name == $label) | "\(.number)|\(.title)"' 2>/dev/null | sort -u)
        
        if [[ -n "$issues_with_label" ]]; then
            [[ -n "$entry_body" ]] && entry_body+=$'\n\n'
            entry_body+="$header"
            entry_body+=$'\n'
            
            while IFS='|' read -r issue_num issue_title; do
                [[ -z "$issue_num" ]] && continue
                
                # Add issue as main bullet
                entry_body+=$'\n'
                entry_body+="- **${issue_title}** (#${issue_num})"
                
                # Find related commits (containing #N or issue-N)
                local related_commits
                related_commits=$(echo "$commits_since_tag" | grep -E "#${issue_num}[^0-9]|#${issue_num}$|issue-${issue_num}" | head -10 || true)
                
                if [[ -n "$related_commits" ]]; then
                    while IFS= read -r commit_line; do
                        [[ -z "$commit_line" ]] && continue
                        # Extract just the message part (after hash)
                        local commit_msg
                        commit_msg=$(echo "$commit_line" | sed 's/^[a-f0-9]* //')
                        # Remove issue reference from commit message to avoid duplication
                        commit_msg=$(echo "$commit_msg" | sed -E "s/ *\(#${issue_num}\)//g; s/ *#${issue_num}//g")
                        # Add as sub-bullet
                        entry_body+=$'\n'
                        entry_body+="  - ${commit_msg}"
                    done <<< "$related_commits"
                fi
            done <<< "$issues_with_label"
        fi
    done
    
    # =========================================================================
    # Add orphan commits (not linked to any issue)
    # =========================================================================
    if [[ -n "$commits_since_tag" ]]; then
        # Find commits not referencing any issue number
        local orphan_commits
        orphan_commits=$(echo "$commits_since_tag" | grep -vE '#[0-9]+' | head -20 || true)
        
        # Only add if there are meaningful orphan commits (not merge commits, not version bumps)
        local filtered_orphans
        filtered_orphans=$(echo "$orphan_commits" | grep -vE '^[a-f0-9]+ (Merge|chore\(release\)|chore: sync)' || true)
        
        if [[ -n "$filtered_orphans" ]]; then
            [[ -n "$entry_body" ]] && entry_body+=$'\n\n'
            entry_body+="### Changed"
            entry_body+=$'\n'
            
            while IFS= read -r commit_line; do
                [[ -z "$commit_line" ]] && continue
                local commit_msg
                commit_msg=$(echo "$commit_line" | sed 's/^[a-f0-9]* //')
                entry_body+=$'\n'
                entry_body+="- ${commit_msg}"
            done <<< "$filtered_orphans"
        fi
    fi
    
    # If nothing found, add placeholder
    if [[ -z "$entry_body" ]]; then
        entry_body="### Changed"$'\n\n'
        entry_body+="- Version bump"
    fi
    
    echo "$entry_body"
}

#
# build_full_entry - Build complete CHANGELOG entry with version header
#
build_full_entry() {
    local content="$1"
    local entry_date
    entry_date=$(date '+%Y-%m-%d')
    
    local entry="## [${ARG_VERSION}] - ${entry_date}"
    if [[ -n "$content" ]]; then
        entry+=$'\n\n'
        entry+="$content"
    fi
    
    echo "$entry"
}

#
# insert_into_changelog - Insert entry at correct position in CHANGELOG.md
#
# Follows Keep a Changelog standard:
#   1. Header (# Changelog + description + footer)
#   2. [Unreleased] section
#   3. Released versions (newest first) <-- Insert here
#
insert_into_changelog() {
    local entry="$1"
    local changelog="$PROJECT_PATH/CHANGELOG.md"
    
    # Create CHANGELOG if it doesn't exist
    if [[ ! -f "$changelog" ]]; then
        cat > "$changelog" << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
EOF
        [[ "$ARG_VERBOSE" == "1" ]] && log_info "Created new CHANGELOG.md"
    fi
    
    local tmp_file="$changelog.tmp"
    local unreleased_line=0
    local first_version_line=0
    local line_num=0
    
    # Find key lines in the CHANGELOG
    while IFS= read -r line; do
        (( line_num += 1 ))
        
        # Find [Unreleased] section
        if [[ "$line" =~ ^##\ \[Unreleased\] ]]; then
            unreleased_line=$line_num
        fi
        
        # Find first released version
        if [[ "$line" =~ ^##\ \[[0-9]+\.[0-9]+\.[0-9]+\] && $first_version_line -eq 0 ]]; then
            first_version_line=$line_num
        fi
    done < "$changelog"
    
    [[ "$ARG_VERBOSE" == "1" ]] && {
        log_info "CHANGELOG structure:"
        echo "  Total lines: $line_num"
        echo "  [Unreleased] at line: ${unreleased_line:-'not found'}"
        echo "  First version at line: ${first_version_line:-'not found'}"
    }
    
    # Determine insertion point
    local insert_after_line=0
    
    if [[ $unreleased_line -gt 0 ]]; then
        # Insert after [Unreleased] section
        local in_unreleased=0
        local unreleased_end=$unreleased_line
        line_num=0
        
        while IFS= read -r line; do
            (( line_num += 1 ))
            
            if [[ $line_num -eq $unreleased_line ]]; then
                in_unreleased=1
                continue
            fi
            
            if [[ $in_unreleased -eq 1 && "$line" =~ ^##\ \[ ]]; then
                unreleased_end=$((line_num - 1))
                break
            fi
        done < "$changelog"
        
        if [[ $in_unreleased -eq 1 && $unreleased_end -eq $unreleased_line ]]; then
            unreleased_end=$line_num
        fi
        
        insert_after_line=$unreleased_end
    elif [[ $first_version_line -gt 0 ]]; then
        insert_after_line=$((first_version_line - 1))
    else
        insert_after_line=$(wc -l < "$changelog" | tr -d ' ')
    fi
    
    [[ "$ARG_VERBOSE" == "1" ]] && echo "  Insert after line: $insert_after_line"
    
    # Build the new CHANGELOG
    # Strip trailing blank lines from head output, then add controlled spacing
    local total_lines
    total_lines=$(wc -l < "$changelog" | tr -d ' ')
    
    {
        # Content before insertion (strip trailing blank lines)
        head -n "$insert_after_line" "$changelog" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
        # Single blank line before entry
        echo ""
        # The entry itself
        printf '%s\n' "$entry"
        # Blank line after entry (if there's more content)
        if [[ $insert_after_line -lt $total_lines ]]; then
            echo ""
            # Remaining content (strip leading blank lines)
            tail -n +$((insert_after_line + 1)) "$changelog" | sed '/./,$!d'
        fi
    } > "$tmp_file"
    
    mv "$tmp_file" "$changelog"
}

#
# lint_changelog - Validate CHANGELOG.md with markdownlint
#
lint_changelog() {
    local changelog="$PROJECT_PATH/CHANGELOG.md"
    
    log_info "Validating CHANGELOG.md markdown..."
    
    if ! docker run --rm -v "$PROJECT_PATH:/workspace:ro" -w /workspace \
        node:24-alpine npx markdownlint-cli2 "CHANGELOG.md" 2>&1; then
        log_error "CHANGELOG.md has markdown linting violations\n\nTo fix:\n  make lint-md FILE=CHANGELOG.md"
    fi
    
    log_success "CHANGELOG.md passed markdown linting"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    parse_args "$@"
    
    # Get content
    local content
    content=$(get_changelog_content)
    
    # Build full entry
    local entry
    entry=$(build_full_entry "$content")
    
    if [[ "$ARG_DRY_RUN" == "1" ]]; then
        # Dry-run mode: preview only (output to stdout)
        echo "$entry"
        
        # Optionally lint (validates what would be written)
        if [[ "$ARG_LINT" == "1" ]]; then
            log_info "Lint validation would run after writing"
        fi
    else
        # Default: write to CHANGELOG.md
        insert_into_changelog "$entry"
        log_success "CHANGELOG.md updated with v${ARG_VERSION} entry"
        
        # Optionally lint
        if [[ "$ARG_LINT" == "1" ]]; then
            lint_changelog
        fi
    fi
}

main "$@"
