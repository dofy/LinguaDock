#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo_root/PopClip/LinguaDock.popclipext"
output_file="$repo_root/PopClip/LinguaDock.popclipextz"

ditto -c -k --sequesterRsrc --keepParent "$source_dir" "$output_file"
echo "Built $output_file"
