#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for bundle in phoenix/phoenix.min.js phoenix_live_view/phoenix_live_view.min.js phoenix_html/phoenix_html.js; do
  package=${bundle%/*}
  file=${bundle#*/}
  if ! cmp -s "deps/$package/priv/static/$file" "priv/static/vendor/$file"; then
    echo "Vendored $file differs from the locked $package package. Re-copy it before release." >&2
    exit 1
  fi
done
