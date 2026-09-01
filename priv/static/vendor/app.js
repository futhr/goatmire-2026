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
  SpeakerNotes: {
    mounted() {
      this.currentSlide = this.el.dataset.currentSlide;
      this.handleNoteClick = (event) => {
        const note = event.target.closest(".speaker-note");

        if (note?.classList.contains("current")) {
          this.scrollToCurrent("auto");
        }
      };
      this.handleViewportChange = () => this.scrollToCurrent("auto");

      this.el.addEventListener("click", this.handleNoteClick);
      window.addEventListener("resize", this.handleViewportChange);
      this.scrollToCurrent("auto");
      requestAnimationFrame(() => this.scrollToCurrent("auto"));
    },
    updated() {
      const nextSlide = this.el.dataset.currentSlide;

      if (nextSlide !== this.currentSlide) {
        this.currentSlide = nextSlide;
        this.scrollToCurrent("auto");
      }
    },
    destroyed() {
      this.el.removeEventListener("click", this.handleNoteClick);
      window.removeEventListener("resize", this.handleViewportChange);
    },
    disconnected() {
      this.el.classList.add("disconnected");
    },
    reconnected() {
      this.el.classList.remove("disconnected");
      this.scrollToCurrent("auto");
    },
    scrollToCurrent(behavior) {
      const current = this.el.querySelector(".speaker-note.current");
      if (!current) return;

      this.fittedNote?.style.removeProperty("--speaker-current-font-size");
      this.fittedNote = current;

      const controls = this.el.querySelector(".speaker-controls");
      const paragraph = current.querySelector(".speaker-note-paragraph");

      if (controls && paragraph) {
        const maximumHeight = controls.getBoundingClientRect().top - 40;
        const naturalSize = Number.parseFloat(getComputedStyle(paragraph).fontSize);

        if (current.offsetHeight > maximumHeight) {
          let smaller = 22;
          let larger = naturalSize;

          for (let attempt = 0; attempt < 8; attempt += 1) {
            const candidate = (smaller + larger) / 2;
            current.style.setProperty("--speaker-current-font-size", `${candidate}px`);

            if (current.offsetHeight <= maximumHeight) {
              smaller = candidate;
            } else {
              larger = candidate;
            }
          }

          current.style.setProperty("--speaker-current-font-size", `${smaller}px`);
        }
      }

      const top = window.scrollY + current.getBoundingClientRect().top - 24;
      window.scrollTo({ top: Math.max(0, top), behavior });
    }
  }
};

// Typing in an embedded form must never drive presenter navigation: stop
// field keystrokes before they bubble to the window-level keydown binding.
document.addEventListener("keydown", (event) => {
  if (event.target.closest?.("input, textarea, select, [contenteditable]")) {
    event.stopPropagation();
    return;
  }

  if (
    event.key.toLowerCase() === "f" &&
    !event.altKey &&
    !event.ctrlKey &&
    !event.metaKey
  ) {
    event.preventDefault();
    event.stopPropagation();

    document.fullscreenElement
      ? document.exitFullscreen()
      : document.documentElement.requestFullscreen();
  }
});

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks
});

liveSocket.connect();
window.liveSocket = liveSocket;
