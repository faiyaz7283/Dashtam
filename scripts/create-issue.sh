#!/usr/bin/env bash
# Create GitHub issue and automatically add to project
# Usage: ./scripts/create-issue.sh [OPTIONS]
#
# This script wraps `gh issue create` and automatically adds the issue to the
# Dashtam Platform Development project (https://github.com/users/faiyaz7283/projects/4)
#
# All gh issue create options are supported. After issue creation, the script:
# 1. Adds issue to project
# 2. Optionally sets Service field (via --service flag)
# 3. Optionally sets Priority field (via --priority flag)
# 4. Optionally sets Quarter field (via --quarter flag)
#
# Examples:
#   ./scripts/create-issue.sh --title "Bug fix" --body "Description" --label bug
#   ./scripts/create-issue.sh --title "Feature" --body "..." --service API --priority P1
#   ./scripts/create-issue.sh --title "Task" --service Platform --quarter Backlog

set -euo pipefail

PROJECT_NUMBER=4
PROJECT_OWNER="faiyaz7283"
PROJECT_ID="PVT_kwHOAhT1384BNJhd"

# Extract our custom flags
SERVICE=""
PRIORITY=""
QUARTER=""
PARENT=""
GH_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --service)
            SERVICE="$2"
            shift 2
            ;;
        --priority)
            PRIORITY="$2"
            shift 2
            ;;
        --quarter)
            QUARTER="$2"
            shift 2
            ;;
        --parent)
            PARENT="$2"
            shift 2
            ;;
        *)
            GH_ARGS+=("$1")
            shift
            ;;
    esac
done

# Create issue and capture URL
echo "Creating issue..."
ISSUE_URL=$(gh issue create "${GH_ARGS[@]}")

if [[ -z "$ISSUE_URL" ]]; then
    echo "Error: Failed to create issue"
    exit 1
fi

echo "✅ Issue created: $ISSUE_URL"

# Add to project
echo "Adding to project..."
gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --url "$ISSUE_URL"
echo "✅ Added to project"

# Set parent issue (sub-issue relationship) if provided
if [[ -n "$PARENT" ]]; then
    echo "Setting parent issue..."
    
    # Extract parent issue number
    if [[ "$PARENT" =~ ^[0-9]+$ ]]; then
        PARENT_NUMBER="$PARENT"
    elif [[ "$PARENT" =~ /([0-9]+)$ ]]; then
        PARENT_NUMBER="${BASH_REMATCH[1]}"
    else
        echo "  ⚠️  Invalid parent issue format: $PARENT (use issue number or URL)"
        PARENT=""
    fi
    
    if [[ -n "$PARENT_NUMBER" ]]; then
        # Extract issue number from created issue
        ISSUE_NUMBER=$(basename "$ISSUE_URL")
        REPO_NAME=$(echo "$ISSUE_URL" | sed -E 's|https://github.com/[^/]+/([^/]+)/.*|\1|')
        
        # Get parent issue node ID
        PARENT_NODE_ID=$(gh api graphql -f query="
        {
          repository(owner: \"$PROJECT_OWNER\", name: \"$REPO_NAME\") {
            issue(number: $PARENT_NUMBER) {
              id
            }
          }
        }" --jq '.data.repository.issue.id')
        
        # Get child issue node ID
        CHILD_NODE_ID=$(gh api graphql -f query="
        {
          repository(owner: \"$PROJECT_OWNER\", name: \"$REPO_NAME\") {
            issue(number: $ISSUE_NUMBER) {
              id
            }
          }
        }" --jq '.data.repository.issue.id')
        
        if [[ -n "$PARENT_NODE_ID" && -n "$CHILD_NODE_ID" ]]; then
            # Add issue body reference (GitHub doesn't have native sub-issue API)
            # Add "Part of #N" to child issue body
            CURRENT_BODY=$(gh issue view "$ISSUE_NUMBER" --json body --jq '.body')
            NEW_BODY="**Part of #$PARENT_NUMBER**\n\n$CURRENT_BODY"
            gh issue edit "$ISSUE_NUMBER" --body "$NEW_BODY"
            
            # Also add comment to parent issue
            gh issue comment "$PARENT_NUMBER" --body "Sub-issue created: #$ISSUE_NUMBER"
            
            echo "  ✅ Linked to parent issue #$PARENT_NUMBER"
        else
            echo "  ⚠️  Could not link to parent issue #$PARENT_NUMBER"
        fi
    fi
fi

# Set custom fields if provided
if [[ -n "$SERVICE" || -n "$PRIORITY" || -n "$QUARTER" ]]; then
    echo "Setting project metadata..."
    
    # Extract issue number and repo from URL
    ISSUE_NUMBER=$(basename "$ISSUE_URL")
    REPO_NAME=$(echo "$ISSUE_URL" | sed -E 's|https://github.com/[^/]+/([^/]+)/.*|\1|')
    
    # Get project item ID
    ITEM_ID=$(gh api graphql -f query="
    {
      repository(owner: \"$PROJECT_OWNER\", name: \"$REPO_NAME\") {
        issue(number: $ISSUE_NUMBER) {
          projectItems(first: 10) {
            nodes {
              id
              project {
                id
              }
            }
          }
        }
      }
    }" --jq ".data.repository.issue.projectItems.nodes[] | select(.project.id == \"$PROJECT_ID\") | .id")
    
    if [[ -z "$ITEM_ID" ]]; then
        echo "Warning: Could not find item in project, skipping metadata"
    else
        # Get field IDs and option IDs
        FIELDS=$(gh api graphql -f query="
        {
          user(login: \"$PROJECT_OWNER\") {
            projectV2(number: $PROJECT_NUMBER) {
              fields(first: 20) {
                nodes {
                  ... on ProjectV2SingleSelectField {
                    id
                    name
                    options {
                      id
                      name
                    }
                  }
                }
              }
            }
          }
        }")
        
        # Set Service
        if [[ -n "$SERVICE" ]]; then
            FIELD_ID=$(echo "$FIELDS" | jq -r ".data.user.projectV2.fields.nodes[] | select(.name == \"Service\") | .id")
            OPTION_ID=$(echo "$FIELDS" | jq -r ".data.user.projectV2.fields.nodes[] | select(.name == \"Service\") | .options[] | select(.name == \"$SERVICE\") | .id")
            
            if [[ -n "$FIELD_ID" && -n "$OPTION_ID" ]]; then
                gh api graphql -f query="
                mutation {
                  updateProjectV2ItemFieldValue(input: {
                    projectId: \"$PROJECT_ID\"
                    itemId: \"$ITEM_ID\"
                    fieldId: \"$FIELD_ID\"
                    value: {
                      singleSelectOptionId: \"$OPTION_ID\"
                    }
                  }) {
                    projectV2Item {
                      id
                    }
                  }
                }" > /dev/null
                echo "  ✅ Service = $SERVICE"
            else
                echo "  ⚠️  Service '$SERVICE' not found"
            fi
        fi
        
        # Set Priority
        if [[ -n "$PRIORITY" ]]; then
            FIELD_ID=$(echo "$FIELDS" | jq -r ".data.user.projectV2.fields.nodes[] | select(.name == \"Priority\") | .id")
            OPTION_ID=$(echo "$FIELDS" | jq -r ".data.user.projectV2.fields.nodes[] | select(.name == \"Priority\") | .options[] | select(.name == \"$PRIORITY\") | .id")
            
            if [[ -n "$FIELD_ID" && -n "$OPTION_ID" ]]; then
                gh api graphql -f query="
                mutation {
                  updateProjectV2ItemFieldValue(input: {
                    projectId: \"$PROJECT_ID\"
                    itemId: \"$ITEM_ID\"
                    fieldId: \"$FIELD_ID\"
                    value: {
                      singleSelectOptionId: \"$OPTION_ID\"
                    }
                  }) {
                    projectV2Item {
                      id
                    }
                  }
                }" > /dev/null
                echo "  ✅ Priority = $PRIORITY"
            else
                echo "  ⚠️  Priority '$PRIORITY' not found"
            fi
        fi
        
        # Set Quarter
        if [[ -n "$QUARTER" ]]; then
            FIELD_ID=$(echo "$FIELDS" | jq -r ".data.user.projectV2.fields.nodes[] | select(.name == \"Quarter\") | .id")
            OPTION_ID=$(echo "$FIELDS" | jq -r ".data.user.projectV2.fields.nodes[] | select(.name == \"Quarter\") | .options[] | select(.name == \"$QUARTER\") | .id")
            
            if [[ -n "$FIELD_ID" && -n "$OPTION_ID" ]]; then
                gh api graphql -f query="
                mutation {
                  updateProjectV2ItemFieldValue(input: {
                    projectId: \"$PROJECT_ID\"
                    itemId: \"$ITEM_ID\"
                    fieldId: \"$FIELD_ID\"
                    value: {
                      singleSelectOptionId: \"$OPTION_ID\"
                    }
                  }) {
                    projectV2Item {
                      id
                    }
                  }
                }" > /dev/null
                echo "  ✅ Quarter = $QUARTER"
            else
                echo "  ⚠️  Quarter '$QUARTER' not found"
            fi
        fi
    fi
fi

echo ""
echo "🎉 Done! View issue: $ISSUE_URL"
