// ES-module LiveView bootstrap over the vendored framework bundles in this
// directory — no Node toolchain, and external because the router's CSP
// (`script-src 'self'`) forbids inline scripts.
//
// Exposed for the stage: `liveSocket.enableLatencySim(1000)` in the console
// makes the round trip visible when explaining that the conflict check runs
// inside the request rather than after it.
const { LiveSocket } = window.LiveView;
const { Socket } = window.Phoenix;

const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;

const hooks = {
  // Fades the floating presenter chrome after a few idle seconds, like video
  // player controls; any pointer movement brings it back.
  IdleChrome: {
    mounted() {
      let timer;

      this.wake = () => {
        this.el.classList.remove("idle");
        clearTimeout(timer);
        timer = setTimeout(() => this.el.classList.add("idle"), 3000);
      };

      this.el.addEventListener("mousemove", this.wake);
      this.el.addEventListener("touchstart", this.wake);
      this.wake();
    },
    updated() {
      this.wake();
    },
    destroyed() {
      this.el.removeEventListener("mousemove", this.wake);
      this.el.removeEventListener("touchstart", this.wake);
    }
  },

  Fullscreen: {
    mounted() {
      this.el.addEventListener("click", () => {
        document.fullscreenElement
          ? document.exitFullscreen()
          : document.documentElement.requestFullscreen();
      });
    }
  },

  TimerReset: {
    mounted() {
      this.el.addEventListener("dblclick", () => this.pushEvent("reset_clock", {}));
    }
  }
};

// Typing in an embedded form must never drive presenter navigation: stop
// field keystrokes before they bubble to the window-level keydown binding.
document.addEventListener("keydown", (event) => {
  if (event.target.closest?.("input, textarea, select, [contenteditable]")) {
    event.stopPropagation();
  }
});

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks
});

liveSocket.connect();
window.liveSocket = liveSocket;
