.PHONY: help create-issue release rollback lint-md lint-md-check lint-md-fix md-check

help:
	@echo "Dashtam Meta Repo - Available Commands"
	@echo ""
	@echo "  make create-issue     Create GitHub issue and add to project"
	@echo "  make release          Prepare release (version bump, CHANGELOG, PR)"
	@echo "  make rollback         Rollback a release (by phase)"
	@echo ""
	@echo "Usage examples:"
	@echo "  make create-issue TITLE='Bug fix' BODY='Description' LABELS='bug'"
	@echo "  make create-issue TITLE='Feature' SERVICE='API' PRIORITY='P1 - High'"
	@echo "  make create-issue TITLE='Sub-issue' PARENT=1 SERVICE='Platform'"
	@echo ""
	@echo "  make release VERSION=1.2.0                # Auto-detect from pwd"
	@echo "  make release PROJECT=api VERSION=1.2.0    # Explicit project"
	@echo "  make release PROJECT=api                  # Interactive (prompts)"
	@echo "  make release VERSION=1.2.0 DRY_RUN=1      # Preview only"
	@echo "  make release VERSION=1.2.0 VERBOSE=1      # Show detailed output"
	@echo "  make release VERSION=1.2.0 YES=1          # Skip confirmations"
	@echo ""
	@echo "  make rollback VERSION=1.9.3               # Auto-detect phase"
	@echo "  make rollback PROJECT=api VERSION=1.9.3   # Explicit project"
	@echo "  make rollback VERSION=1.9.3 PHASE=2       # Force specific phase"
	@echo "  make rollback VERSION=1.9.3 DRY_RUN=1     # Preview only"
	@echo ""
	@echo "  make lint-md FILE=docs/guides/file.md  # Lint markdown file"
	@echo ""
	@echo "For direct script usage with more options:"
	@echo "  ./scripts/create-issue.sh --title 'Title' --body 'Body' --service Platform --parent 1"
	@echo "  ./scripts/release.sh --version 1.2.0 --milestone 'v1.2.0' --dry-run"
	@echo "  ./scripts/release-rollback.sh --project api --version 1.9.3 --dry-run --verbose"

# Create issue with automatic project addition
# Usage: make create-issue TITLE="..." BODY="..." [SERVICE=...] [PRIORITY=...] [QUARTER=...] [LABELS=...] [PARENT=...]
create-issue:
	@if [ -z "$(TITLE)" ]; then \
		echo "Error: TITLE is required"; \
		echo "Usage: make create-issue TITLE='Issue title' BODY='Description' [SERVICE=API] [PRIORITY='P1 - High']"; \
		exit 1; \
	fi
	@ARGS="--title '$(TITLE)'"; \
	[ -n "$(BODY)" ] && ARGS="$$ARGS --body '$(BODY)'"; \
	[ -n "$(LABELS)" ] && ARGS="$$ARGS --label '$(LABELS)'"; \
	[ -n "$(ASSIGNEE)" ] && ARGS="$$ARGS --assignee '$(ASSIGNEE)'"; \
	[ -n "$(MILESTONE)" ] && ARGS="$$ARGS --milestone '$(MILESTONE)'"; \
	[ -n "$(SERVICE)" ] && ARGS="$$ARGS --service '$(SERVICE)'"; \
	[ -n "$(PRIORITY)" ] && ARGS="$$ARGS --priority '$(PRIORITY)'"; \
	[ -n "$(QUARTER)" ] && ARGS="$$ARGS --quarter '$(QUARTER)'"; \
	[ -n "$(PARENT)" ] && ARGS="$$ARGS --parent '$(PARENT)'"; \
	eval "./scripts/create-issue.sh $$ARGS"

# Prepare release (version bump, CHANGELOG, create PR)
# Usage: make release [PROJECT=api] VERSION=1.2.0 [MILESTONE="v1.2.0"] [DRY_RUN=1] [VERBOSE=1] [YES=1]
release:
	@ARGS=""; \
	[ -n "$(PROJECT)" ] && ARGS="$$ARGS --project $(PROJECT)"; \
	[ -n "$(VERSION)" ] && ARGS="$$ARGS --version $(VERSION)"; \
	[ -n "$(MILESTONE)" ] && ARGS="$$ARGS --milestone '$(MILESTONE)'"; \
	[ -n "$(DRY_RUN)" ] && [ "$(DRY_RUN)" = "1" ] && ARGS="$$ARGS --dry-run"; \
	[ -n "$(VERBOSE)" ] && [ "$(VERBOSE)" = "1" ] && ARGS="$$ARGS --verbose"; \
	[ -n "$(YES)" ] && [ "$(YES)" = "1" ] && ARGS="$$ARGS --yes"; \
	if [ -z "$$ARGS" ]; then \
		./scripts/release.sh --help; \
	else \
		eval "./scripts/release.sh $$ARGS"; \
	fi

# Rollback a release (by phase)
# Usage: make rollback [PROJECT=api] VERSION=1.9.3 [PHASE=2] [DRY_RUN=1] [VERBOSE=1] [YES=1]
rollback:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		echo "Usage: make rollback VERSION=1.9.3 [PROJECT=api] [PHASE=2] [DRY_RUN=1]"; \
		exit 1; \
	fi
	@ARGS=""; \
	[ -n "$(PROJECT)" ] && ARGS="$$ARGS --project $(PROJECT)"; \
	[ -n "$(VERSION)" ] && ARGS="$$ARGS --version $(VERSION)"; \
	[ -n "$(PHASE)" ] && ARGS="$$ARGS --phase $(PHASE)"; \
	[ -n "$(DRY_RUN)" ] && [ "$(DRY_RUN)" = "1" ] && ARGS="$$ARGS --dry-run"; \
	[ -n "$(VERBOSE)" ] && [ "$(VERBOSE)" = "1" ] && ARGS="$$ARGS --verbose"; \
	[ -n "$(YES)" ] && [ "$(YES)" = "1" ] && ARGS="$$ARGS --yes"; \
	eval "./scripts/release-rollback.sh $$ARGS"

# ==============================================================================
# MARKDOWN LINTING
# ==============================================================================
# 
# Professional markdown linting with flexible targeting and safety controls.
# 
# Commands:
#   lint-md      - Check markdown files (non-destructive, CI-friendly)
#   lint-md-fix  - Fix markdown issues with safety controls
# 
# Targeting Options (apply to both commands):
#   (none)                          - All markdown files in project
#   FILE=path/to/file.md            - Single file
#   FILES="file1.md file2.md"       - Multiple specific files
#   DIR=docs/guides                 - Entire directory
#   DIRS="docs tests"               - Multiple directories
#   PATTERN="docs/**/*.md"          - Custom glob pattern
#   PATHS="README.md docs/"         - Mixed files and directories
# 
# Safety Options (lint-md-fix only):
#   DRY_RUN=1                       - Preview changes without applying
#   DIFF=1                          - Generate patch file for manual review
# 
# Examples:
#   make lint-md                              # Check all files
#   make lint-md FILE=README.md               # Check single file
#   make lint-md DIR=docs/guides              # Check directory
#   make lint-md-fix DRY_RUN=1                # Preview all fixes
#   make lint-md-fix FILE=README.md           # Fix single file (prompt)
#   make lint-md-fix DIR=docs DIFF=1          # Generate patch for docs/
# 
# ==============================================================================

# Configuration
MARKDOWN_LINT_IMAGE := node:24-alpine
MARKDOWN_LINT_CMD := npx markdownlint-cli2
MARKDOWN_BASE_PATTERN := '**/*.md'
# Note: Ignore patterns are configured in .markdownlint-cli2.jsonc

# ----------------------------------------------------------------------------
# Helper: Build lint target from parameters
# ----------------------------------------------------------------------------
define build_lint_target
	$(eval LINT_TARGET := )
	$(eval TARGET_DESC := )
	
	$(if $(FILE),\
		$(eval LINT_TARGET := '$(FILE)')\
		$(eval TARGET_DESC := $(FILE)))
	
	$(if $(FILES),\
		$(eval LINT_TARGET := $(FILES))\
		$(eval TARGET_DESC := $(FILES)))
	
	$(if $(DIR),\
		$(eval LINT_TARGET := '$(DIR)/**/*.md')\
		$(eval TARGET_DESC := $(DIR)/))
	
	$(if $(DIRS),\
		$(eval LINT_TARGET := $(foreach dir,$(DIRS),'$(dir)/**/*.md'))\
		$(eval TARGET_DESC := $(DIRS)))
	
	$(if $(PATTERN),\
		$(eval LINT_TARGET := '$(PATTERN)')\
		$(eval TARGET_DESC := $(PATTERN)))
	
	$(if $(PATHS),\
		$(eval LINT_TARGET := $(PATHS))\
		$(eval TARGET_DESC := $(PATHS)))
	
	$(if $(LINT_TARGET),,\
		$(eval LINT_TARGET := $(MARKDOWN_BASE_PATTERN))\
		$(eval TARGET_DESC := all markdown files))
endef

# ----------------------------------------------------------------------------
# Command: lint-md
# ----------------------------------------------------------------------------
lint-md:
	@$(call build_lint_target)
	@echo "🔍 Linting: $(TARGET_DESC)"
	@docker run --rm \
		-v $(PWD):/workspace:ro \
		-w /workspace \
		$(MARKDOWN_LINT_IMAGE) \
		sh -c "$(MARKDOWN_LINT_CMD) $(LINT_TARGET) || exit 1"
	@echo "✅ Markdown linting complete!"

# CI-friendly alias (identical to lint-md)
lint-md-check: lint-md

# ----------------------------------------------------------------------------
# Command: lint-md-fix
# ----------------------------------------------------------------------------
lint-md-fix:
	@$(call build_lint_target)
	@$(call _lint_md_fix_execute)

# ----------------------------------------------------------------------------
# Helper: Execute lint-md-fix based on mode
# ----------------------------------------------------------------------------
define _lint_md_fix_execute
	@if [ "$(DRY_RUN)" = "1" ]; then \
		$(call _lint_md_fix_dry_run); \
	elif [ "$(DIFF)" = "1" ]; then \
		$(call _lint_md_fix_diff); \
	else \
		$(call _lint_md_fix_apply); \
	fi
endef

# ----------------------------------------------------------------------------
# Helper: Dry-run mode (preview changes)
# ----------------------------------------------------------------------------
define _lint_md_fix_dry_run
	echo "🔍 DRY RUN: Previewing changes for $(TARGET_DESC)..."; \
	echo "   (no files will be modified)"; \
	echo ""; \
	docker run --rm \
		-v $(PWD):/workspace:ro \
		-w /workspace \
		$(MARKDOWN_LINT_IMAGE) \
		sh -c "$(MARKDOWN_LINT_CMD) --fix --dry-run $(LINT_TARGET) 2>&1 \
			| grep -E '(would fix|Error|Warning)' \
			|| echo '   ✅ No fixable issues found'"; \
	echo ""; \
	echo "💡 To apply fixes, run without DRY_RUN:"; \
	echo "   make lint-md-fix $(if $(FILE),FILE=$(FILE))$(if $(DIR),DIR=$(DIR))$(if $(PATTERN),PATTERN=$(PATTERN))"
endef

# ----------------------------------------------------------------------------
# Helper: DIFF mode (generate patch file)
# ----------------------------------------------------------------------------
define _lint_md_fix_diff
	echo "📝 Generating diff patch for $(TARGET_DESC)..."; \
	echo ""; \
	timestamp=$$(date +%Y%m%d_%H%M%S); \
	patch_file="markdown-lint-fix_$$timestamp.patch"; \
	echo "📄 Patch file: $$patch_file"; \
	echo ""; \
	docker run --rm \
		-v $(PWD):/workspace \
		-w /workspace \
		$(MARKDOWN_LINT_IMAGE) \
		sh -c "git diff > /tmp/before.patch && \
			$(MARKDOWN_LINT_CMD) --fix $(LINT_TARGET) && \
			git diff > /workspace/$$patch_file && \
			git checkout -- . && \
			cat /workspace/$$patch_file"; \
	echo ""; \
	echo "✅ Patch generated: $$patch_file"; \
	echo ""; \
	echo "📖 Next steps:"; \
	echo "   1. Review patch: cat $$patch_file"; \
	echo "   2. Apply patch:  git apply $$patch_file"; \
	echo "   3. Verify:       make lint-md"; \
	echo "   4. Commit:       git add . && git commit -m 'docs: fix markdown linting'"
endef

# ----------------------------------------------------------------------------
# Helper: Apply mode (fix with confirmation)
# ----------------------------------------------------------------------------
define _lint_md_fix_apply
	echo "⚠️  WARNING: This will modify markdown files!"; \
	echo ""; \
	echo "   Target: $(TARGET_DESC)"; \
	echo ""; \
	echo "   Changes will be applied immediately."; \
	echo "   Review changes with 'git diff' after running."; \
	echo ""; \
	echo "💡 Tip: Use DRY_RUN=1 to preview, or DIFF=1 to generate patch"; \
	echo "   Example: make lint-md-fix $(if $(FILE),FILE=$(FILE))$(if $(DIR),DIR=$(DIR)) DRY_RUN=1"; \
	echo ""; \
	read -p "Continue with fix? (yes/no): " confirm; \
	if [ "$$confirm" != "yes" ]; then \
		echo "❌ Operation cancelled"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "🔧 Fixing markdown files: $(TARGET_DESC)..."; \
	docker run --rm \
		-v $(PWD):/workspace \
		-w /workspace \
		$(MARKDOWN_LINT_IMAGE) \
		$(MARKDOWN_LINT_CMD) --fix $(LINT_TARGET); \
	echo ""; \
	echo "✅ Auto-fix complete!"; \
	echo ""; \
	echo "📖 Next steps:"; \
	echo "   1. Review changes:  git diff"; \
	echo "   2. Verify linting:  make lint-md"; \
	echo "   3. Commit changes:  git add . && git commit -m 'docs: fix markdown linting'"; \
	echo "   4. Rollback if needed: git checkout -- ."
endef

# Convenience alias
md-check: lint-md
