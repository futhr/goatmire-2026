# Dependency maintenance

During release preparation, `git_or_local` uses sibling `beamlens_web` and
`ex_maude` checkouts when present. Otherwise, it uses the Git revisions in
`mix.exs` and `mix.lock`. Those revisions must be pushed before a fresh remote
checkout can resolve them.

`beamlens_web` is the only forked dependency. Its `theme-config` revision
`42f6e9b98ad04fc4f89b47d77183505ba21cd8aa` adds consumer theming in one commit
on upstream `efe1b7f139cf256173beef85636b13e310bb3f79`. The fork is consumed
through Git; upstream owns its Hex releases. `ex_maude` is an original project,
not a fork. BeamLens itself comes from Hex.

Updates reviewed for this audit:

- [Mint 1.10.0](https://github.com/elixir-mint/mint/blob/main/CHANGELOG.md):
  bounded HTTP response parsing; fixes CVE-2026-82728 and CVE-2026-82729.
- [Elixir 1.19.6](https://github.com/elixir-lang/elixir/releases/tag/v1.19.6)
  and [OTP 28.5.0.6](https://github.com/erlang/otp/releases/tag/OTP-28.5.0.6):
  maintenance and security fixes, pinned consistently in local tooling and CI.
- [Dialyxir 1.4.8](https://github.com/jeremyjh/dialyxir/releases/tag/1.4.8):
  OTP 28 warning support and ignore handling.
- [ExDoc 0.40.4](https://github.com/elixir-lang/ex_doc/blob/main/CHANGELOG.md):
  reproducible output and navigation fixes.
- [Tesla 1.21.3](https://github.com/elixir-tesla/tesla/blob/master/CHANGELOG.md):
  HTTP streaming, upload, and retry handling fixes.
- [QUIC 1.8.2](https://github.com/benoitc/erlang_quic/blob/main/CHANGELOG.md):
  connection lifecycle and HTTP/3 response completion fixes.

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
