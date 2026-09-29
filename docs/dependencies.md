# Dependency maintenance

`ex_maude` comes from Hex under the constraint in `mix.exs` and the version in
`mix.lock`. It does not use a sibling checkout.

The in-house libraries may contain unreleased changes even when their local
version strings still match Hex. Report released-package and local-candidate
verification separately, identifying the candidate commit and dirty state.
A passing sibling build does not establish that the fixes are in the package
this application's lockfile installs. Test candidates in temporary consumers;
do not rewrite this lockfile or widen constraints merely to test them.

`git_or_local` uses a sibling `beamlens_web` checkout when present; otherwise
it uses the pinned Git revision in `mix.exs` and `mix.lock`. A local sibling can
therefore differ from the locked dependency. Release verification must also
run in an isolated checkout without that sibling. The pinned revision must
already be available remotely for a fresh checkout to resolve it.

`beamlens_web` is the only forked dependency. Its `theme-config` revision
`6497405c34cc1e05405919a631665ff280d9a9dd` is two commits on upstream
`efe1b7f139cf256173beef85636b13e310bb3f79`: consumer theming, and a one-line
fix so the library compiles without warnings on Elixir 1.20 (its own lockfile
moved to LiveView 1.2.12 for the same reason). Upstream `main` has not moved
since that base, so the branch needed no rebase. The fork is consumed through
Git; upstream owns its Hex releases. `ex_maude` is an original project,
not a fork. BeamLens itself comes from Hex.

Updates reviewed for this audit:

- [Mint 1.11.0](https://github.com/elixir-mint/mint/blob/main/CHANGELOG.md):
  fixes the HTTP/1 response-smuggling and HTTP/2 memory-exhaustion advisories
  EEF-CVE-2026-82672, -91043, -92103 and -94194 reported against 1.10.x. The
  earlier `ignore_advisories` entry for Decimal is gone: Hex no longer reports
  CVE-2026-32686 against the locked 3.1.1, so `mix hex.audit` runs unfiltered.
- [Elixir 1.20.4](https://github.com/elixir-lang/elixir/releases/tag/v1.20.4)
  and [OTP 28.5.0.6](https://github.com/erlang/otp/releases/tag/OTP-28.5.0.6):
  pinned consistently in `.tool-versions`, the container build and CI. The
  1.20 compiler reports unused `require`s and checks more call types; both
  findings it raised here were real and are fixed in the source, not silenced.
- [ExMaude 0.4.3](https://github.com/futhr/ex_maude/blob/main/CHANGELOG.md):
  integer precision in numeric comparisons and rejection of malformed rule
  collections in the IoT checker this demo runs. Updating it removes the
  installed interpreter; run `mix maude.install --version 3.5.1` afterwards.
- [Tortoise311 0.12.3](https://github.com/smartrent/tortoise311/blob/main/CHANGELOG.md):
  ignores late results instead of crashing the connection. Its publish payload
  type is now `iolist()`, so the MQTT transport passes JSON as iodata.
- Phoenix 1.8.15 and LiveView 1.2.12: `priv/static/vendor` was re-copied from
  the locked packages, which `scripts/check-vendor.sh` verifies.
- [lazy_html 0.1.13](https://github.com/dashbitco/lazy_html/blob/main/CHANGELOG.md)
  (test only): fixes the mutation-XSS advisory EEF-CVE-2026-92106.
- [Dialyxir 1.4.8](https://github.com/jeremyjh/dialyxir/releases/tag/1.4.8):
  OTP 28 warning support and ignore handling.
- [ExDoc 0.40.4](https://github.com/elixir-lang/ex_doc/blob/main/CHANGELOG.md):
  reproducible output and navigation fixes.

Lua remains on BeamLens's compatible 0.4 series. Upgrade that constraint through
BeamLens rather than overriding it in this application.

The optional [Livebook 0.19.9 release](https://github.com/livebook-dev/livebook/releases/tag/v0.19.9)
fixes notebook import path traversal, widget event forwarding, shell escaping,
and Teams authentication issues. Its image stays loopback-only and now includes
the pinned Maude interpreter. It is built from pinned upstream source on the
same patched Elixir/OTP runtime as the demo. `docker/livebook.mix.lock` records
its production dependency updates, and the build rejects Hex advisories.
Bun 1.3.10 is confined to that container build and regenerates the assets against
the locked Phoenix libraries.

Open item: that lock now trips its own audit. The pinned Livebook commit depends
on `nimble_zta` 0.1.2 (retired, EEF-CVE-2026-91187) and `cowlib` 2.20.0
(EEF-CVE-2026-43966, -43969), so the optional `livebook` image does not build
until the pin moves to a Livebook release that resolves them and the patch and
lock are regenerated. The stage does not use this container.

The small `docker/livebook-security.patch` widens two upstream constraints:

- [Protobuf 0.17.0](https://github.com/elixir-protobuf/protobuf/blob/main/CHANGELOG.md)
  includes the nested decode limit introduced in 0.16.1. Livebook does not call
  the deprecated constructors removed in 0.15.
- [Req 0.6.3](https://github.com/wojtekmach/req/blob/main/CHANGELOG.md)
  includes multipart escaping and safer response decoding defaults. The notebook
  setup and local server checks do not depend on automatic archive decoding.

The patch does not change Livebook's source version. It is a locally maintained
security build; repeat its container and notebook checks when changing this lock.

Integration references reviewed include [ExMaude’s usage rules](https://github.com/futhr/ex_maude/blob/main/usage-rules.md),
[Elixir process anti-patterns](https://elixir.hexdocs.pm/process-anti-patterns.html),
[LiveView async operations](https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html#module-async-operations),
and the [Codex app-server protocol](https://learn.chatgpt.com/docs/app-server).
Codex tool restrictions are checked against the installed CLI protocol; the
integration refuses an unexpected MCP inventory before starting a model turn.
