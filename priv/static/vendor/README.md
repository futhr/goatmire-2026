# Vendored framework JS

Prebuilt browser bundles copied verbatim from the Hex packages, so the dashboard needs no Node toolchain. Re-copy after upgrading the corresponding dependency:

- `phoenix.min.js` ← `deps/phoenix/priv/static/`
- `phoenix_live_view.min.js` ← `deps/phoenix_live_view/priv/static/`
- `phoenix_html.js` ← `deps/phoenix_html/priv/static/`

`app.js` is ours: the plain-globals LiveView bootstrap. It is a static file rather than an inline script because the router's CSP (`script-src 'self'`) forbids inline execution.
