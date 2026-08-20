#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
hook_dir="${repo_root}/.git/hooks"

if [ ! -d "${repo_root}/.git" ]; then
    echo "ERROR: ${repo_root} is not a git repo — clone it first."
    exit 1
fi

mkdir -p "${hook_dir}"
ln -sf "../../scripts/pre-commit-secret-scan.sh" "${hook_dir}/pre-commit"
chmod +x "${repo_root}/scripts/pre-commit-secret-scan.sh"

echo "OK — pre-commit hook installed at ${hook_dir}/pre-commit"
echo "   (blocks credential-shaped strings from being committed)"
