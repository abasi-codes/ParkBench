import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import Chat from "./chat"

// Hooks
let Hooks = {}

// Search autocomplete with debounce
Hooks.SearchAutocomplete = {
  mounted() {
    let timeout;
    this.el.addEventListener("input", (e) => {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        this.pushEvent("autocomplete", {q: e.target.value});
      }, 300);
    });
  }
}

// Character count
Hooks.CharacterCount = {
  mounted() {
    const input = this.el.querySelector("textarea, input");
    const counter = this.el.querySelector(".char-count");
    const max = parseInt(input.getAttribute("maxlength") || "5000");

    if (input && counter) {
      input.addEventListener("input", () => {
        const remaining = max - input.value.length;
        counter.textContent = remaining;
        counter.classList.toggle("warning", remaining < 50);
      });
    }
  }
}

// Photo upload with progress (LiveView handles progress natively via live_file_input)
Hooks.PhotoUpload = {
  mounted() {
    // LiveView's live_file_input handles upload progress automatically.
    // This hook is kept for backward compatibility with any manual file inputs.
    this.el.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (file) {
        const progress = this.el.parentElement.querySelector(".upload-progress");
        if (progress) progress.style.display = "block";
      }
    });
  }
}

// Idle detection (10 min)
Hooks.IdleDetection = {
  mounted() {
    let idleTimeout;
    const resetTimer = () => {
      clearTimeout(idleTimeout);
      idleTimeout = setTimeout(() => {
        this.pushEvent("user_idle", {});
      }, 600000); // 10 minutes
    };

    ["mousemove", "keydown", "click", "scroll"].forEach(event => {
      document.addEventListener(event, resetTimer);
    });
    resetTimer();
  }
}

// Toast notifications
Hooks.Toast = {
  mounted() {
    this.handleEvent("show_toast", ({message}) => {
      const toast = document.createElement("div");
      toast.className = "toast";
      toast.innerHTML = `<span class="toast-icon">\u2709</span><span>${message}</span>`;
      this.el.appendChild(toast);

      setTimeout(() => {
        toast.classList.add("dismissing");
        toast.addEventListener("animationend", () => toast.remove());
      }, 5000);
    });
  }
}

// Comment submit on Enter (Shift+Enter for newline)
Hooks.CommentSubmitOnEnter = {
  mounted() {
    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        const form = e.target.closest("form");
        if (form) form.dispatchEvent(new Event("submit", {bubbles: true, cancelable: true}));
      }
    });
  }
}

// Photo lightbox
Hooks.PhotoLightbox = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      const img = e.target.closest("img");
      if (!img) return;
      const src = img.src;
      if (!src) return;

      const overlay = document.createElement("div");
      overlay.className = "lightbox-overlay";
      overlay.innerHTML = `<img src="${src}" class="lightbox-img" /><button class="lightbox-close">&times;</button>`;
      document.body.appendChild(overlay);

      const close = () => overlay.remove();
      overlay.querySelector(".lightbox-close").addEventListener("click", close);
      overlay.addEventListener("click", (ev) => { if (ev.target === overlay) close(); });
      document.addEventListener("keydown", function handler(ev) {
        if (ev.key === "Escape") { close(); document.removeEventListener("keydown", handler); }
      });
    });
  }
}

// Infinite scroll
Hooks.InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver((entries) => {
      const entry = entries[0];
      if (entry.isIntersecting) {
        this.pushEvent("load_more", {});
      }
    }, { rootMargin: "200px" });
    this.observer.observe(this.el);
  },
  destroyed() {
    if (this.observer) this.observer.disconnect();
  }
}

// Buddy list - periodically refresh online status
Hooks.BuddyList = {
  mounted() {
    // Refresh online status every 60 seconds
    this.timer = setInterval(() => {
      this.pushEvent("refresh_buddy_list", {});
    }, 60000);
  },
  destroyed() {
    if (this.timer) clearInterval(this.timer);
  }
}

// LiveSocket setup
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

liveSocket.connect()
window.liveSocket = liveSocket

// Initialize chat if user is logged in
if (document.getElementById("pb-chat-config")) {
  window.__spChat = new Chat();
}

// Handle logout links with POST method
document.addEventListener("click", (e) => {
  const link = e.target.closest("[data-method='post']");
  if (link) {
    e.preventDefault();
    const form = document.createElement("form");
    form.method = "POST";
    form.action = link.getAttribute("href");
    const csrf = document.createElement("input");
    csrf.type = "hidden";
    csrf.name = "_csrf_token";
    csrf.value = link.getAttribute("data-csrf") || csrfToken;
    form.appendChild(csrf);
    document.body.appendChild(form);
    form.submit();
  }
});
