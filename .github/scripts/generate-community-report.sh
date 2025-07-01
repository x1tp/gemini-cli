#!/usr/bin/env bash

# Community Report Generation Script
# This script generates a comprehensive community contribution report

# Ensure we're using bash 4+ for associative arrays
if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
    echo "❌ Error: Bash version 4+ required for associative arrays. Current version: $BASH_VERSION"
    exit 1
fi

set -e

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly TIMESTAMP=$(date -u +'%Y-%m-%d %H:%M:%S UTC')

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Validate environment variables
validate_environment() {
    local required_vars=("GH_TOKEN" "REPO" "DAYS")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "Required environment variable $var is not set"
            return 1
        fi
    done
}

# Validate inputs
validate_inputs() {
    if [[ ! "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]] || [[ "$DAYS" -gt 365 ]]; then
        log_error "DAYS must be a number between 1 and 365"
        return 1
    fi
}

# Initialize date range
initialize_dates() {
    START_DATE=$(date -u -d "$DAYS days ago" +'%Y-%m-%d')
    END_DATE=$(date -u +'%Y-%m-%d')
    log_info "Generating report for contributions from $START_DATE to $END_DATE"
}

# Cache for user status to reduce API calls
declare -A author_is_googler
declare -i api_calls=0
declare -i cache_hits=0

# Check if user is a Googler - returns "googler" or "community"
check_googler_status() {
    local author=$1
    
    # Skip bots
    if [[ "$author" == *"[bot]" ]]; then
        author_is_googler[$author]="community"
        echo "community"
        return
    fi
    
    # Check cache first
    if [[ -n "${author_is_googler[$author]:-}" ]]; then
        ((cache_hits++))
        echo "${author_is_googler[$author]}"
        return
    fi

    ((api_calls++))
    
    # Use set +e temporarily to handle the API call without exiting
    set +e
    if gh api "orgs/googlers/members/$author" --silent 2>/dev/null; then
        log_info "🧑‍💻 $author is a Googler"
        author_is_googler[$author]="googler"
        echo "googler"
    else
        log_info "🌍 $author is a community contributor"
        author_is_googler[$author]="community"
        echo "community"
    fi
    set -e
}

# Main execution function
main() {
    log_info "🚀 Starting community report generation..."
    
    # Enable debug mode if requested
    if [[ "$DEBUG" == "true" ]]; then
        set -x
        log_info "🐛 Debug mode enabled"
    fi

    validate_environment
    validate_inputs
    initialize_dates
    
    # Initialize counters
    googler_issues=0
    non_googler_issues=0
    googler_prs=0
    non_googler_prs=0

    log_info "🔎 Fetching issues and pull requests..."
    ITEMS_JSON=$(gh search issues --repo "$REPO" "created:>$START_DATE" --json author,isPullRequest --limit 1000)
    
    total_items=$(echo "$ITEMS_JSON" | jq '. | length')
    log_success "Found $total_items items to process"
    
    local processed_items=0
    for row in $(echo "${ITEMS_JSON}" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }
        author=$(_jq '.author.login')
        is_pr=$(_jq '.isPullRequest')

        if [[ -z "$author" || "$author" == "null" ]]; then
            continue
        fi

        ((processed_items++))
        if [[ $((processed_items % 50)) -eq 0 ]]; then
            log_info "📈 Processed $processed_items/$total_items items..."
        fi

        user_type=$(check_googler_status "$author")
        if [[ "$user_type" == "googler" ]]; then
            if [[ "$is_pr" == "true" ]]; then
                ((googler_prs++))
            else
                ((googler_issues++))
            fi
        else
            if [[ "$is_pr" == "true" ]]; then
                ((non_googler_prs++))
            else
                ((non_googler_issues++))
            fi
        fi
    done

    log_success "Processed all issues and PRs"

    # Initialize discussion counters
    googler_discussions=0
    non_googler_discussions=0

    log_info "🗣️ Fetching discussions..."
    DISCUSSION_QUERY='
    query($q: String!) {
      search(query: $q, type: DISCUSSION, first: 100) {
        nodes {
          ... on Discussion {
            author {
              login
            }
          }
        }
      }
    }'
    
    # Use set +e temporarily for discussions as they might fail
    set +e
    DISCUSSIONS_JSON=$(gh api graphql -f q="repo:$REPO created:>$START_DATE" -f query="$DISCUSSION_QUERY" 2>/dev/null)
    discussions_success=$?
    set -e
    
    if [[ $discussions_success -eq 0 ]]; then
        for row in $(echo "${DISCUSSIONS_JSON}" | jq -r '.data.search.nodes[] | @base64' 2>/dev/null || echo ""); do
            if [[ -n "$row" ]]; then
                _jq() {
                    echo ${row} | base64 --decode | jq -r ${1}
                }
                author=$(_jq '.author.login')

                if [[ -z "$author" || "$author" == "null" ]]; then
                    continue
                fi

                user_type=$(check_googler_status "$author")
                if [[ "$user_type" == "googler" ]]; then
                    ((googler_discussions++))
                else
                    ((non_googler_discussions++))
                fi
            fi
        done
        log_success "Processed all discussions"
    else
        log_warning "Failed to fetch discussions, continuing without discussion data"
    fi

    log_info "✍️ Generating report content..."
    
    # Performance statistics
    if [[ "$DEBUG" == "true" ]]; then
        log_info "📊 Performance Statistics:"
        log_info "  - API calls made: $api_calls"
        log_info "  - Cache hits: $cache_hits"
        if [[ $((api_calls + cache_hits)) -gt 0 ]]; then
            log_info "  - Cache hit rate: $(( cache_hits * 100 / (api_calls + cache_hits) ))%"
        fi
    fi
    
    TOTAL_ISSUES=$((googler_issues + non_googler_issues))
    TOTAL_PRS=$((googler_prs + non_googler_prs))
    TOTAL_DISCUSSIONS=$((googler_discussions + non_googler_discussions))
    TOTAL_CONTRIBUTIONS=$((TOTAL_ISSUES + TOTAL_PRS + TOTAL_DISCUSSIONS))
    
    # Calculate percentages
    if [[ $TOTAL_CONTRIBUTIONS -gt 0 ]]; then
        COMMUNITY_PERCENTAGE=$(( (non_googler_issues + non_googler_prs + non_googler_discussions) * 100 / TOTAL_CONTRIBUTIONS ))
    else
        COMMUNITY_PERCENTAGE=0
    fi

    # Determine most active category
    local most_active_category
    if [[ $TOTAL_PRS -ge $TOTAL_ISSUES ]] && [[ $TOTAL_PRS -ge $TOTAL_DISCUSSIONS ]]; then
        most_active_category="Pull Requests ($TOTAL_PRS)"
    elif [[ $TOTAL_ISSUES -ge $TOTAL_DISCUSSIONS ]]; then
        most_active_category="Issues ($TOTAL_ISSUES)"
    else
        most_active_category="Discussions ($TOTAL_DISCUSSIONS)"
    fi

    # Calculate cache hit rate safely
    local cache_rate=0
    if [[ $((api_calls + cache_hits)) -gt 0 ]]; then
        cache_rate=$(( cache_hits * 100 / (api_calls + cache_hits) ))
    fi

    REPORT_BODY=$(cat <<EOF
### 💖 Community Contribution Report

**Period:** $START_DATE to $END_DATE

| Category | Googlers | Community | Total |
|---|---:|---:|---:|
| **Issues** | $googler_issues | $non_googler_issues | **$TOTAL_ISSUES** |
| **Pull Requests** | $googler_prs | $non_googler_prs | **$TOTAL_PRS** |
| **Discussions** | $googler_discussions | $non_googler_discussions | **$TOTAL_DISCUSSIONS** |
| **📊 TOTALS** | **$((googler_issues + googler_prs + googler_discussions))** | **$((non_googler_issues + non_googler_prs + non_googler_discussions))** | **$TOTAL_CONTRIBUTIONS** |

### 📈 Key Metrics
- **Community Contribution Rate:** ${COMMUNITY_PERCENTAGE}%
- **Most Active Category:** $most_active_category
- **Data Quality:** ${cache_rate}% cache hit rate

---
_This report was generated automatically by a GitHub Action. Report generated at $TIMESTAMP_
EOF
)

    # Output for GitHub Actions
    if [[ -n "$GITHUB_OUTPUT" ]]; then
        echo "report_body<<EOF" >> "$GITHUB_OUTPUT"
        echo "$REPORT_BODY" >> "$GITHUB_OUTPUT"
        echo "EOF" >> "$GITHUB_OUTPUT"
    fi

    log_success "📊 Community Contribution Report generated successfully"
    echo "$REPORT_BODY"
    
    log_success "🎉 Community report generation completed successfully!"
}

# Execute main function
main "$@"
