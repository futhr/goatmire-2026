#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hook_dir="$(git rev-parse --path-format=absolute --git-path hooks)"
hook="${hook_dir}/pre-commit"

if [ -e "$hook" ] && ! rg -q 'goatmire-secret-hook|scripts/pre-commit-secret-scan.sh' "$hook"; then
    echo "Existing pre-commit hook preserved. Add scripts/pre-commit-secret-scan.sh to it manually." >&2
    exit 1
fi

mkdir -p "$hook_dir"
# Remove only the recognized Goatmire hook/link; never write through a symlink.
rm -f "$hook"
cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
# goatmire-secret-hook: resolves the active worktree at commit time.
set -euo pipefail
exec "$(git rev-parse --show-toplevel)/scripts/pre-commit-secret-scan.sh"
HOOK
chmod +x "$hook"
echo "Installed Goatmire pre-commit hook at $hook"
