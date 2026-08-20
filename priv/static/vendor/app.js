// Plain-globals LiveView bootstrap over the vendored framework bundles in
// this directory — no Node toolchain, and external because the router's CSP
// (`script-src 'self'`) forbids inline scripts.
//
// Exposed for the stage: `liveSocket.enableLatencySim(1000)` in the console
// makes the round trip visible when explaining that the conflict check runs
// inside the request rather than after it.
(function () {
  "use strict";

  var csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content");

  var liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
    params: { _csrf_token: csrfToken }
  });

  liveSocket.connect();
  window.liveSocket = liveSocket;
})();
