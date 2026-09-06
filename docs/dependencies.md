# Dependency maintenance

The lockfile is authoritative. Local sibling checkouts do not override it.
For temporary library development, change the dependency explicitly and keep
that local change out of release commits.

`beamlens_web` is the only forked dependency. On 2026-09-06, upstream
`beamlens/beamlens_web` main was `efe1b7f139cf256173beef85636b13e310bb3f79`.
Rebasing the fork's `theme-config` branch onto it was a no-op: its two custom
commits already follow that upstream head. The pinned result is
`a8bcb2340d9a67cb91265d929f0f286d3425ad24`. `ex_maude` is an original project,
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
