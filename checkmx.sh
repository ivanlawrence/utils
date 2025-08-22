#!/usr/bin/env bash
# checkmx.sh
#
# Usage:
#   ./checkmx.sh [-p N] [@dnsserver] [file]
#
# Examples:
#   ./checkmx.sh domains.txt
#   ./checkmx.sh -p 10 @8.8.8.8 domains.txt
#   cat domains.txt | ./checkmx.sh @1.1.1.1
#
# Output:
#   stdout = domains that HAVE MX records
#   stderr = domains that LACK MX records

set -euo pipefail

dns_server=""
file=""
parallelism=4   # default parallel jobs

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p)
            if [[ $# -lt 2 ]]; then
                echo "Error: -p requires a number" >&2
                exit 1
            fi
            parallelism="$2"
            shift 2
            ;;
        @*)
            dns_server="$1"
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            file="$1"
            shift
            ;;
    esac
done

# Input: file or stdin
if [[ -n "$file" ]]; then
    input=$(cat "$file")
else
    input=$(cat -)
fi

# Function to check a single domain
check_domain() {
    local domain="$1"
    local dns_server="$2"

    [[ -z "$domain" ]] && return 0

    # Query MX, suppress dig warnings/errors
    if dig $dns_server +short MX "$domain" 2>/dev/null | grep -q .; then
        echo "$domain"          # HAS MX -> stdout
    else
        echo "$domain" >&2      # NO MX  -> stderr
    fi
}

export -f check_domain
export dns_server

# Run in parallel
printf "%s\n" "$input" | \
    xargs -P "$parallelism" -n 1 bash -c 'check_domain "$0" "$dns_server"' 

# end
