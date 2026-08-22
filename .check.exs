[
  parallel: false,
  fix: false,
  skipped: true,
  tools: [
    {:compiler, command: "mix compile --warnings-as-errors"},
    {:formatter, command: "mix format --check-formatted"},
    {:credo, command: "mix credo --strict", require_files: []},
    {:doctor, command: "mix doctor --summary"},
    {:sobelow, command: "mix sobelow --config --compact"},
    {:mix_audit, command: "mix deps.audit"},
    {:hex_audit, command: "mix hex.audit"},
    {:unused_deps, command: "mix deps.unlock --check-unused"},
    {:secret_scan, command: "scripts/pre-commit-secret-scan.sh"},
    {:ex_unit, command: "mix coveralls --warnings-as-errors"},
    {:dialyzer, command: "mix dialyzer --format short"},
    {:ex_doc, command: "mix docs --warnings-as-errors"},
    {:release, "mix release --overwrite", env: %{"MIX_ENV" => "prod"}},
    {:compose, "scripts/check-compose.sh"},
    {:gettext, false},
    {:npm_test, false}
  ]
]
