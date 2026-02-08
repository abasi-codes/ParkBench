import {Socket, Presence} from "phoenix"

const MAX_OPEN_WINDOWS = 3;

const AVATAR_COLORS = [
  "#6d84b4", "#7FB685", "#D4726A", "#E8A033",
  "#8b6bb0", "#5b9bd5", "#c9736e", "#6aaa5c"
];

const REACTION_EMOJIS = ["\u2764\ufe0f", "\ud83d\ude02", "\ud83d\ude2e", "\ud83d\udc4d", "\ud83d\ude22", "\ud83d\ude4f"];

function escapeHtml(str) {
  if (!str) return "";
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

function formatTime(isoString) {
  const d = new Date(isoString);
  let h = d.getHours(), m = d.getMinutes();
  const ampm = h >= 12 ? "pm" : "am";
  h = h % 12 || 12;
  return `${h}:${m < 10 ? "0" + m : m}${ampm}`;
}

function formatDate(isoString) {
  const d = new Date(isoString);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const msgDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diff = today - msgDay;

  if (diff === 0) return "Today";
  if (diff === 86400000) return "Yesterday";

  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];
  return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

function dayKey(isoString) {
  const d = new Date(isoString);
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

function pickColor(id) {
  if (!id) return AVATAR_COLORS[0];
  let hash = 0;
  const str = String(id);
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash + str.charCodeAt(i)) | 0;
  }
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length];
}

function getInitials(name) {
  if (!name) return "?";
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
  return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
}

export default class Chat {
  constructor() {
    const config = document.getElementById("pb-chat-config");
    if (!config) return;

    this.userId = config.dataset.userId;
    this.token = config.dataset.socketToken;
    this.friends = [];
    this.friendsLoaded = false;
    this.onlineUserIds = new Set();
    this.windows = {}; // threadId -> { friendId, friendName, minimized, unread, messages, channel, reactions }
    this.contactsOpen = true;
    this.contactsFilter = "";
    this.typingTimers = {}; // threadId -> timer
    this.typingUsers = {}; // threadId -> { userId: { name, timer } }
    this.presences = {};
    this.activeReactionPicker = null; // { threadId, messageId }

    this.root = document.getElementById("pb-chat-root");
    if (!this.root) return;

    this.restoreState();
    this.connect();
    this.bindEvents();
    this.render();
  }

  // ── Socket & Channels ──────────────────────────────────────────────

  connect() {
    this.socket = new Socket("/socket", { params: { token: this.token } });
    this.socket.connect();

    // Join presence lobby
    this.presenceChannel = this.socket.channel("presence:lobby", {});
    this.presenceChannel.join()
      .receive("ok", () => {
        // Request friends list
        this.presenceChannel.push("get_friends", {})
          .receive("ok", ({ friends }) => {
            this.friends = friends;
            this.friendsLoaded = true;
            this.render();
          })
          .receive("error", (err) => {
            console.error("Failed to get friends:", err);
            this.friendsLoaded = true;
            this.render();
          })
          .receive("timeout", () => {
            console.error("get_friends timed out");
            this.friendsLoaded = true;
            this.render();
          });
      })
      .receive("error", (err) => {
        console.error("Failed to join presence lobby:", err);
        this.friendsLoaded = true;
        this.render();
      })
      .receive("timeout", () => {
        console.error("Presence lobby join timed out");
        this.friendsLoaded = true;
        this.render();
      });

    this.presenceChannel.onError(() => {
      if (!this.friendsLoaded) {
        this.friendsLoaded = true;
        this.render();
      }
    });

    this.presenceChannel.onClose(() => {
      if (!this.friendsLoaded) {
        this.friendsLoaded = true;
        this.render();
      }
    });

    this.presenceChannel.on("presence_state", state => {
      this.presences = Presence.syncState(this.presences, state);
      this.updateOnlineStatus();
    });

    this.presenceChannel.on("presence_diff", diff => {
      this.presences = Presence.syncDiff(this.presences, diff);
      this.updateOnlineStatus();
    });
  }

  updateOnlineStatus() {
    this.onlineUserIds = new Set(Object.keys(this.presences));
    this.render();
  }

  // ── Event Binding ──────────────────────────────────────────────────

  bindEvents() {
    this.root.addEventListener("click", (e) => {
      // Close reaction picker if clicking outside
      if (this.activeReactionPicker && !e.target.closest(".chat-reaction-picker")) {
        this.activeReactionPicker = null;
        this.render();
      }

      const target = e.target.closest("[data-chat-action]");
      if (!target) return;

      const action = target.dataset.chatAction;
      const friendId = target.dataset.friendId;
      const threadId = target.dataset.threadId;
      const messageId = target.dataset.messageId;
      const emoji = target.dataset.emoji;

      switch (action) {
        case "open-chat":
          this.openChat(friendId);
          break;
        case "close-window":
          e.stopPropagation();
          this.closeWindow(threadId);
          break;
        case "minimize-window":
          e.stopPropagation();
          this.minimizeWindow(threadId);
          break;
        case "restore-window":
          this.restoreWindow(threadId);
          break;
        case "toggle-contacts":
          this.contactsOpen = !this.contactsOpen;
          this.render();
          break;
        case "send-message":
          this.sendFromButton(threadId);
          break;
        case "react":
          this.sendReaction(threadId, messageId, emoji);
          break;
        case "view-shared-post":
          window.location.href = `/posts/${target.dataset.postId}`;
          break;
      }
    });

    // Double-click to show reaction picker
    this.root.addEventListener("dblclick", (e) => {
      const bubble = e.target.closest(".chat-msg-bubble");
      if (!bubble) return;

      const msgEl = bubble.closest(".chat-msg");
      if (!msgEl) return;

      const threadId = msgEl.dataset.threadId;
      const messageId = msgEl.dataset.messageId;
      if (!threadId || !messageId) return;

      e.preventDefault();
      this.activeReactionPicker = { threadId, messageId };
      this.render();
    });

    this.root.addEventListener("keydown", (e) => {
      if (e.target.classList.contains("chat-input-field")) {
        const threadId = e.target.dataset.threadId;
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault();
          this.sendMessage(threadId, e.target.value);
          e.target.value = "";
        } else {
          this.sendTyping(threadId);
        }
      }

      if (e.target.classList.contains("chat-search-input")) {
        // Allow typing, handled by input event
      }
    });

    this.root.addEventListener("input", (e) => {
      if (e.target.classList.contains("chat-search-input")) {
        this.contactsFilter = e.target.value.toLowerCase();
        this.render();
      }
    });

    // Close reaction picker on Escape
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && this.activeReactionPicker) {
        this.activeReactionPicker = null;
        this.render();
      }
    });
  }

  // ── Chat Operations ────────────────────────────────────────────────

  openChat(friendId) {
    // Check if already open for this friend
    for (const [tid, win] of Object.entries(this.windows)) {
      if (win.friendId === friendId) {
        win.minimized = false;
        win.unread = 0;
        this.render();
        this.scrollToBottom(tid);
        return;
      }
    }

    this.presenceChannel.push("open_chat", { friend_id: friendId })
      .receive("ok", ({ thread_id }) => {
        this.joinThread(thread_id, friendId);
      })
      .receive("error", (err) => {
        console.error("Failed to open chat:", err);
      });
  }

  joinThread(threadId, friendId) {
    if (this.windows[threadId]) {
      this.windows[threadId].minimized = false;
      this.render();
      return;
    }

    const friend = this.friends.find(f => f.id === friendId);
    const friendName = friend ? friend.display_name : "Chat";

    const channel = this.socket.channel(`chat:${threadId}`, {});
    channel.join()
      .receive("ok", ({ messages }) => {
        // Enforce max open windows
        this.enforceMaxWindows();

        this.windows[threadId] = {
          friendId,
          friendName,
          minimized: false,
          unread: 0,
          messages: messages || [],
          channel,
          seen: false,
          reactions: {} // messageId -> [ { emoji, user_id, user_name } ]
        };

        channel.on("new_message", (msg) => {
          this.handleNewMessage(threadId, msg);
        });

        channel.on("typing", ({ user_id, display_name }) => {
          if (user_id !== this.userId) {
            this.showTyping(threadId, user_id, display_name);
          }
        });

        channel.on("stop_typing", ({ user_id }) => {
          this.hideTyping(threadId, user_id);
        });

        channel.on("read_receipt", ({ user_id }) => {
          if (user_id !== this.userId) {
            this.windows[threadId].seen = true;
            this.render();
          }
        });

        channel.on("reaction", ({ message_id, user_id, user_name, emoji, action }) => {
          this.handleReaction(threadId, message_id, user_id, user_name, emoji, action);
        });

        this.saveState();
        this.render();
        this.scrollToBottom(threadId);
      })
      .receive("error", (err) => {
        console.error("Failed to join chat channel:", err);
      });
  }

  enforceMaxWindows() {
    const openWindows = Object.entries(this.windows)
      .filter(([, w]) => !w.minimized);

    if (openWindows.length >= MAX_OPEN_WINDOWS) {
      // Minimize the oldest open window
      const [oldestId] = openWindows[0];
      this.windows[oldestId].minimized = true;
    }
  }

  handleNewMessage(threadId, msg) {
    const win = this.windows[threadId];
    if (!win) return;

    // Avoid duplicate messages
    if (win.messages.some(m => m.id === msg.id)) return;

    win.messages.push(msg);
    win.seen = false;

    if (msg.sender_id !== this.userId) {
      if (win.minimized) {
        win.unread = (win.unread || 0) + 1;
      } else {
        // Mark as read
        win.channel.push("mark_read", {});
      }
    }

    this.render();
    if (!win.minimized) {
      this.scrollToBottom(threadId);
    }
  }

  handleReaction(threadId, messageId, userId, userName, emoji, action) {
    const win = this.windows[threadId];
    if (!win) return;

    if (!win.reactions[messageId]) {
      win.reactions[messageId] = [];
    }

    if (action === "added") {
      // Remove existing same reaction from same user, then add
      win.reactions[messageId] = win.reactions[messageId]
        .filter(r => !(r.user_id === userId && r.emoji === emoji));
      win.reactions[messageId].push({ emoji, user_id: userId, user_name: userName });
    } else if (action === "removed") {
      win.reactions[messageId] = win.reactions[messageId]
        .filter(r => !(r.user_id === userId && r.emoji === emoji));
    }

    this.render();
  }

  sendMessage(threadId, body) {
    const trimmed = body.trim();
    if (!trimmed) return;

    const win = this.windows[threadId];
    if (!win || !win.channel) return;

    win.channel.push("new_message", { body: trimmed })
      .receive("error", (err) => {
        console.error("Send failed:", err);
      });

    // Clear typing indicator
    this.clearTypingTimer(threadId);
    win.channel.push("stop_typing", {});
  }

  sendFromButton(threadId) {
    const input = this.root.querySelector(`.chat-input-field[data-thread-id="${threadId}"]`);
    if (!input) return;
    this.sendMessage(threadId, input.value);
    input.value = "";
    input.focus();
  }

  sendReaction(threadId, messageId, emoji) {
    const win = this.windows[threadId];
    if (!win || !win.channel) return;

    win.channel.push("react", { message_id: messageId, emoji });
    this.activeReactionPicker = null;
    this.render();
  }

  sendTyping(threadId) {
    const win = this.windows[threadId];
    if (!win || !win.channel) return;

    if (!this.typingTimers[threadId]) {
      win.channel.push("typing", {});
    }

    clearTimeout(this.typingTimers[threadId]);
    this.typingTimers[threadId] = setTimeout(() => {
      win.channel.push("stop_typing", {});
      delete this.typingTimers[threadId];
    }, 3000);
  }

  clearTypingTimer(threadId) {
    clearTimeout(this.typingTimers[threadId]);
    delete this.typingTimers[threadId];
  }

  showTyping(threadId, userId, displayName) {
    if (!this.typingUsers[threadId]) {
      this.typingUsers[threadId] = {};
    }

    clearTimeout(this.typingUsers[threadId][userId]?.timer);

    this.typingUsers[threadId][userId] = {
      name: displayName,
      timer: setTimeout(() => {
        this.hideTyping(threadId, userId);
      }, 4000)
    };

    this.render();
  }

  hideTyping(threadId, userId) {
    if (this.typingUsers[threadId]) {
      clearTimeout(this.typingUsers[threadId][userId]?.timer);
      delete this.typingUsers[threadId][userId];
      if (Object.keys(this.typingUsers[threadId]).length === 0) {
        delete this.typingUsers[threadId];
      }
    }
    this.render();
  }

  closeWindow(threadId) {
    const win = this.windows[threadId];
    if (win && win.channel) {
      win.channel.leave();
    }
    delete this.windows[threadId];
    delete this.typingUsers[threadId];
    this.clearTypingTimer(threadId);
    this.saveState();
    this.render();
  }

  minimizeWindow(threadId) {
    if (this.windows[threadId]) {
      this.windows[threadId].minimized = true;
      this.saveState();
      this.render();
    }
  }

  restoreWindow(threadId) {
    if (this.windows[threadId]) {
      this.windows[threadId].minimized = false;
      this.windows[threadId].unread = 0;

      // Mark as read
      this.windows[threadId].channel?.push("mark_read", {});

      this.enforceMaxWindows();
      this.saveState();
      this.render();
      this.scrollToBottom(threadId);
    }
  }

  scrollToBottom(threadId) {
    requestAnimationFrame(() => {
      const el = this.root.querySelector(`[data-messages-thread="${threadId}"]`);
      if (el) el.scrollTop = el.scrollHeight;
    });
  }

  // ── State Persistence ──────────────────────────────────────────────

  saveState() {
    const state = {};
    for (const [tid, win] of Object.entries(this.windows)) {
      state[tid] = {
        friendId: win.friendId,
        friendName: win.friendName,
        minimized: win.minimized
      };
    }
    try {
      sessionStorage.setItem("pb_chat_windows", JSON.stringify(state));
    } catch (e) { /* ignore */ }
  }

  restoreState() {
    try {
      const saved = sessionStorage.getItem("pb_chat_windows");
      if (!saved) return;

      const state = JSON.parse(saved);
      // Will rejoin these after socket connects
      this._pendingRestore = state;
    } catch (e) { /* ignore */ }
  }

  attemptRestore() {
    if (!this._pendingRestore || this._restored) return;
    this._restored = true;

    for (const [threadId, info] of Object.entries(this._pendingRestore)) {
      this.joinThread(threadId, info.friendId);
      // Restore minimized state after join
      setTimeout(() => {
        if (this.windows[threadId] && info.minimized) {
          this.windows[threadId].minimized = true;
          this.render();
        }
      }, 500);
    }

    delete this._pendingRestore;
  }

  // ── Helpers ────────────────────────────────────────────────────────

  getSortedFriends() {
    let list = this.friends;

    if (this.contactsFilter) {
      list = list.filter(f =>
        f.display_name.toLowerCase().includes(this.contactsFilter)
      );
    }

    return list.sort((a, b) => {
      const aOnline = this.onlineUserIds.has(a.id);
      const bOnline = this.onlineUserIds.has(b.id);
      if (aOnline && !bOnline) return -1;
      if (!aOnline && bOnline) return 1;
      return a.display_name.localeCompare(b.display_name);
    });
  }

  getOnlineCount() {
    return this.friends.filter(f => this.onlineUserIds.has(f.id)).length;
  }

  getGroupedReactions(threadId, messageId) {
    const win = this.windows[threadId];
    if (!win || !win.reactions[messageId]) return [];

    const grouped = {};
    for (const r of win.reactions[messageId]) {
      if (!grouped[r.emoji]) {
        grouped[r.emoji] = { emoji: r.emoji, count: 0, users: [] };
      }
      grouped[r.emoji].count++;
      grouped[r.emoji].users.push(r.user_name);
    }
    return Object.values(grouped);
  }

  // ── Main Render ────────────────────────────────────────────────────

  render() {
    if (!this.root) return;

    // If friends loaded and pending restore, do it
    if (this.friends.length > 0 && this._pendingRestore && !this._restored) {
      this.attemptRestore();
    }

    const openWindows = Object.entries(this.windows).filter(([, w]) => !w.minimized);
    const minimizedWindows = Object.entries(this.windows).filter(([, w]) => w.minimized);

    this.root.innerHTML = `
      <div class="chat-bar">
        ${this.renderMinimized(minimizedWindows)}
        ${this.renderWindows(openWindows)}
        ${this.renderContacts()}
      </div>
    `;
  }

  // ── Contacts Panel ─────────────────────────────────────────────────

  renderContacts() {
    if (!this.contactsOpen) {
      return `
        <div class="chat-contacts" style="height: auto;">
          <div class="chat-contacts-header" data-chat-action="toggle-contacts" role="button">
            <h3>Bench Chat</h3>
          </div>
        </div>
      `;
    }

    const sortedFriends = this.getSortedFriends();
    const onlineFriends = sortedFriends.filter(f => this.onlineUserIds.has(f.id));
    const offlineFriends = sortedFriends.filter(f => !this.onlineUserIds.has(f.id));
    const onlineCount = this.getOnlineCount();

    let listContent;
    if (!this.friendsLoaded) {
      listContent = '<div style="padding: 20px; text-align: center; color: var(--stone); font-size: 12px;">Loading...</div>';
    } else if (sortedFriends.length === 0 && !this.contactsFilter) {
      listContent = '<div style="padding: 20px; text-align: center; color: var(--stone); font-size: 12px;">No friends yet</div>';
    } else if (sortedFriends.length === 0) {
      listContent = '<div style="padding: 20px; text-align: center; color: var(--stone); font-size: 12px;">No matches</div>';
    } else {
      let items = "";

      if (onlineFriends.length > 0) {
        items += '<div class="chat-section-label">Online</div>';
        items += onlineFriends.map(f => this.renderContactItem(f, true)).join("");
      }

      if (offlineFriends.length > 0) {
        items += '<div class="chat-section-label">Offline</div>';
        items += offlineFriends.map(f => this.renderContactItem(f, false)).join("");
      }

      listContent = items;
    }

    return `
      <div class="chat-contacts">
        <div class="chat-contacts-header" data-chat-action="toggle-contacts" role="button">
          <h3>
            Bench Chat
            <span class="online-count">${onlineCount}</span>
          </h3>
          <div class="chat-contacts-header-actions">
            <button class="chat-header-btn" data-chat-action="toggle-contacts" title="Minimize">&minus;</button>
          </div>
        </div>
        <div class="chat-contacts-search">
          <input type="text"
                 class="chat-search-input"
                 placeholder="Search friends..."
                 value="${escapeHtml(this.contactsFilter)}" />
        </div>
        <div class="chat-contacts-list">
          ${listContent}
        </div>
      </div>
    `;
  }

  renderContactItem(friend, online) {
    const color = pickColor(friend.id);
    const initials = getInitials(friend.display_name);
    const statusClass = online ? "online" : "offline";
    const statusText = online ? "Active now" : "Offline";

    // Check unread count across windows for this friend
    let unreadBadge = "";
    for (const [, win] of Object.entries(this.windows)) {
      if (win.friendId === friend.id && win.unread > 0) {
        unreadBadge = `<div class="chat-contact-badge">${win.unread}</div>`;
        break;
      }
    }

    return `
      <div class="chat-contact" data-chat-action="open-chat" data-friend-id="${friend.id}" role="button">
        <div class="chat-contact-avatar" style="background: ${color};">
          ${initials}
          <div class="status-dot ${statusClass}"></div>
        </div>
        <div class="chat-contact-info">
          <div class="chat-contact-name">${escapeHtml(friend.display_name)}</div>
          <div class="chat-contact-status">${statusText}</div>
        </div>
        ${unreadBadge}
      </div>
    `;
  }

  // ── Chat Windows ───────────────────────────────────────────────────

  renderWindows(openWindows) {
    return openWindows.map(([threadId, win]) => {
      const friend = this.friends.find(f => f.id === win.friendId);
      const online = this.onlineUserIds.has(win.friendId);
      const color = pickColor(win.friendId);
      const initials = getInitials(win.friendName);
      const statusClass = online ? "online" : "offline";
      const statusText = online ? "Active now" : "Offline";

      const messagesHtml = this.renderMessages(threadId, win);
      const typingHtml = this.renderTypingIndicator(threadId);

      return `
        <div class="chat-window">
          <div class="chat-window-header">
            <div class="chat-window-avatar" style="background: ${color};">
              ${initials}
              <div class="status-dot ${statusClass}"></div>
            </div>
            <div class="chat-window-name">
              <h4>${escapeHtml(win.friendName)}</h4>
              <span>${statusText}</span>
            </div>
            <div class="chat-window-actions">
              <button class="chat-win-btn" data-chat-action="minimize-window" data-thread-id="${threadId}" title="Minimize">&minus;</button>
              <button class="chat-win-btn" data-chat-action="close-window" data-thread-id="${threadId}" title="Close">&times;</button>
            </div>
          </div>
          <div class="chat-messages" data-messages-thread="${threadId}">
            ${messagesHtml}
            ${typingHtml}
          </div>
          <div class="chat-input-area">
            <div class="chat-input-tools">
              <button class="chat-tool-btn" title="Attach">\u{1F4CE}</button>
            </div>
            <input type="text"
                   class="chat-input-field"
                   data-thread-id="${threadId}"
                   placeholder="Type a message..."
                   autocomplete="off" />
            <button class="chat-send-btn" data-chat-action="send-message" data-thread-id="${threadId}" title="Send">
              <svg viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
            </button>
          </div>
        </div>
      `;
    }).join("");
  }

  renderMessages(threadId, win) {
    const messages = win.messages || [];
    if (messages.length === 0) {
      return '<div style="flex: 1; display: flex; align-items: center; justify-content: center; color: var(--stone); font-size: 12px;">No messages yet</div>';
    }

    let html = "";
    let lastDayKey = null;

    for (let i = 0; i < messages.length; i++) {
      const msg = messages[i];
      const msgDayKey = dayKey(msg.inserted_at);

      // Date divider
      if (msgDayKey !== lastDayKey) {
        html += `
          <div class="chat-date-divider">
            <span>${formatDate(msg.inserted_at)}</span>
          </div>
        `;
        lastDayKey = msgDayKey;
      }

      const isOwn = msg.sender_id === this.userId;
      const msgClass = isOwn ? "sent" : "received";
      const isLast = i === messages.length - 1;

      // Read receipt for last own message
      let readMark = "";
      if (isOwn && win.seen && isLast) {
        readMark = '<span class="chat-msg-read">Seen</span>';
      }

      // AI badge (if message has ai_generated flag)
      let aiBadge = "";
      if (msg.ai_generated) {
        aiBadge = `
          <span class="chat-msg-ai-badge">
            <svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 1a7 7 0 100 14A7 7 0 008 1zm0 2.5a1.25 1.25 0 110 2.5 1.25 1.25 0 010-2.5zM6.5 7h3l-.5 5.5h-2L6.5 7z"/></svg>
            AI
          </span>
        `;
      }

      // Shared post card
      let sharedPostHtml = "";
      if (msg.shared_post_id) {
        sharedPostHtml = `
          <div class="chat-shared-post" data-chat-action="view-shared-post" data-post-id="${msg.shared_post_id}" role="button">
            <div class="chat-shared-label">Shared Post</div>
            <div class="chat-shared-title">${msg.shared_post_title ? escapeHtml(msg.shared_post_title) : "View post"}</div>
            ${msg.shared_post_snippet ? `<div class="chat-shared-snippet">${escapeHtml(msg.shared_post_snippet)}</div>` : ""}
          </div>
        `;
      }

      // Reactions
      const groupedReactions = this.getGroupedReactions(threadId, msg.id);
      let reactionsHtml = "";
      if (groupedReactions.length > 0) {
        reactionsHtml = groupedReactions.map(r =>
          `<span class="chat-msg-reaction" title="${escapeHtml(r.users.join(", "))}">${r.emoji} ${r.count > 1 ? r.count : ""}</span>`
        ).join("");
      }

      // Reaction picker
      let pickerHtml = "";
      if (this.activeReactionPicker &&
          this.activeReactionPicker.threadId === threadId &&
          this.activeReactionPicker.messageId === msg.id) {
        pickerHtml = `
          <div class="chat-reaction-picker" style="
            display: flex;
            gap: 2px;
            background: white;
            border: 1px solid rgba(168, 184, 156, 0.2);
            border-radius: 20px;
            padding: 4px 8px;
            box-shadow: 0 2px 12px rgba(92, 74, 58, 0.15);
            margin-top: 4px;
            ${isOwn ? 'align-self: flex-end;' : 'align-self: flex-start;'}
          ">
            ${REACTION_EMOJIS.map(em =>
              `<span data-chat-action="react"
                     data-thread-id="${threadId}"
                     data-message-id="${msg.id}"
                     data-emoji="${em}"
                     style="cursor: pointer; font-size: 18px; padding: 2px 4px; border-radius: 6px; transition: background 0.15s;"
                     onmouseover="this.style.background='var(--cream)'"
                     onmouseout="this.style.background='transparent'"
                     role="button">${em}</span>`
            ).join("")}
          </div>
        `;
      }

      html += `
        <div class="chat-msg ${msgClass}" data-thread-id="${threadId}" data-message-id="${msg.id}">
          <div class="chat-msg-bubble">${msg.body ? escapeHtml(msg.body) : ""}</div>
          ${sharedPostHtml}
          <div class="chat-msg-time">
            ${formatTime(msg.inserted_at)}
            ${aiBadge}
            ${readMark}
          </div>
          ${reactionsHtml}
          ${pickerHtml}
        </div>
      `;
    }

    return html;
  }

  renderTypingIndicator(threadId) {
    const typing = this.typingUsers[threadId];
    if (!typing || Object.keys(typing).length === 0) return "";

    return `
      <div class="chat-typing">
        <div class="typing-dots">
          <span></span><span></span><span></span>
        </div>
        typing...
      </div>
    `;
  }

  // ── Minimized Bubbles ──────────────────────────────────────────────

  renderMinimized(minimizedWindows) {
    if (minimizedWindows.length === 0) return "";

    return minimizedWindows.map(([threadId, win]) => {
      const online = this.onlineUserIds.has(win.friendId);
      const color = pickColor(win.friendId);
      const initials = getInitials(win.friendName);
      const statusClass = online ? "online" : "offline";

      let badge = "";
      if (win.unread > 0) {
        badge = `<div class="mini-badge">${win.unread}</div>`;
      }

      return `
        <div class="chat-minimized"
             style="background: ${color};"
             data-chat-action="restore-window"
             data-thread-id="${threadId}"
             role="button"
             title="${escapeHtml(win.friendName)}">
          ${initials}
          <div class="status-dot ${statusClass}"></div>
          ${badge}
        </div>
      `;
    }).join("");
  }

  // ── Cleanup ────────────────────────────────────────────────────────

  destroy() {
    if (this.presenceChannel) this.presenceChannel.leave();
    for (const win of Object.values(this.windows)) {
      if (win.channel) win.channel.leave();
    }
    if (this.socket) this.socket.disconnect();
  }
}
