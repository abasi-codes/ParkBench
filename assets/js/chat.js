import {Socket, Presence} from "phoenix"

const MAX_OPEN_WINDOWS = 3;

function escapeHtml(str) {
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

export default class Chat {
  constructor() {
    const config = document.getElementById("pb-chat-config");
    if (!config) return;

    this.userId = config.dataset.userId;
    this.token = config.dataset.socketToken;
    this.friends = [];
    this.friendsLoaded = false;
    this.onlineUserIds = new Set();
    this.windows = {}; // threadId -> { friendId, friendName, minimized, unread, messages, channel }
    this.sidebarOpen = true;
    this.sidebarFilter = "";
    this.typingTimers = {}; // threadId -> timer
    this.typingUsers = {}; // threadId -> { userId, name, timer }
    this.presences = {};

    this.root = document.getElementById("pb-chat-root");
    if (!this.root) return;

    this.restoreState();
    this.connect();
    this.bindEvents();
    this.render();
  }

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

  bindEvents() {
    this.root.addEventListener("click", (e) => {
      const target = e.target.closest("[data-chat-action]");
      if (!target) return;

      const action = target.dataset.chatAction;
      const friendId = target.dataset.friendId;
      const threadId = target.dataset.threadId;

      switch (action) {
        case "open-chat":
          this.openChat(friendId);
          break;
        case "close-window":
          this.closeWindow(threadId);
          break;
        case "minimize-window":
          this.minimizeWindow(threadId);
          break;
        case "restore-window":
          this.restoreWindow(threadId);
          break;
        case "toggle-sidebar":
          this.sidebarOpen = !this.sidebarOpen;
          this.render();
          break;
      }
    });

    this.root.addEventListener("keydown", (e) => {
      if (e.target.classList.contains("pb-chat-input")) {
        const threadId = e.target.dataset.threadId;
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault();
          this.sendMessage(threadId, e.target.value);
          e.target.value = "";
        } else {
          this.sendTyping(threadId);
        }
      }

      if (e.target.classList.contains("pb-chat-sidebar-search")) {
        this.sidebarFilter = e.target.value.toLowerCase();
        this.render();
      }
    });

    this.root.addEventListener("input", (e) => {
      if (e.target.classList.contains("pb-chat-sidebar-search")) {
        this.sidebarFilter = e.target.value.toLowerCase();
        this.render();
      }
    });
  }

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
          seen: false
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

  // State persistence across navigation
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

  // Rendering
  render() {
    if (!this.root) return;

    // If friends loaded and pending restore, do it
    if (this.friends.length > 0 && this._pendingRestore && !this._restored) {
      this.attemptRestore();
    }

    const sortedFriends = this.getSortedFriends();
    const openWindows = Object.entries(this.windows).filter(([, w]) => !w.minimized);
    const minimizedWindows = Object.entries(this.windows).filter(([, w]) => w.minimized);

    this.root.innerHTML = `
      ${this.renderSidebar(sortedFriends)}
      ${this.renderWindows(openWindows)}
      ${this.renderMinimized(minimizedWindows)}
    `;
  }

  getSortedFriends() {
    let list = this.friends;

    if (this.sidebarFilter) {
      list = list.filter(f =>
        f.display_name.toLowerCase().includes(this.sidebarFilter)
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

  renderSidebar(friends) {
    if (!this.sidebarOpen) {
      return `
        <div class="pb-chat-sidebar pb-chat-sidebar--collapsed">
          <div class="pb-chat-sidebar-header" data-chat-action="toggle-sidebar" role="button">
            <span class="pb-chat-sidebar-title">Chat</span>
          </div>
        </div>
      `;
    }

    const friendItems = friends.map(f => {
      const online = this.onlineUserIds.has(f.id);
      const avatarUrl = f.avatar_url || "/images/default-avatar.svg";
      return `
        <div class="pb-chat-friend ${online ? "pb-chat-friend--online" : "pb-chat-friend--offline"}"
             data-chat-action="open-chat" data-friend-id="${f.id}" role="button">
          <div class="pb-chat-friend-avatar">
            <img src="${escapeHtml(avatarUrl)}" alt="" />
            <span class="pb-chat-status-dot ${online ? "pb-chat-status-dot--online" : "pb-chat-status-dot--offline"}"></span>
          </div>
          <span class="pb-chat-friend-name">${escapeHtml(f.display_name)}</span>
        </div>
      `;
    }).join("");

    const headerText = this.friendsLoaded ? `Chat (${this.friends.length})` : "Chat";
    let listContent;
    if (!this.friendsLoaded) {
      listContent = '<div class="pb-chat-empty">Loading...</div>';
    } else if (friendItems) {
      listContent = friendItems;
    } else {
      listContent = '<div class="pb-chat-empty">No friends yet</div>';
    }

    return `
      <div class="pb-chat-sidebar">
        <div class="pb-chat-sidebar-header" data-chat-action="toggle-sidebar" role="button">
          <span class="pb-chat-sidebar-title">${headerText}</span>
        </div>
        <div class="pb-chat-sidebar-search-wrap">
          <input type="text" class="pb-chat-sidebar-search" placeholder="Search friends..."
                 value="${escapeHtml(this.sidebarFilter)}" />
        </div>
        <div class="pb-chat-sidebar-list">
          ${listContent}
        </div>
      </div>
    `;
  }

  renderWindows(openWindows) {
    return openWindows.map(([threadId, win], index) => {
      const messages = (win.messages || []).map(msg => {
        const isOwn = msg.sender_id === this.userId;
        const seenMark = isOwn && win.seen && msg === win.messages[win.messages.length - 1]
          ? '<span class="pb-chat-seen">Seen</span>'
          : '';

        return `
          <div class="pb-chat-msg ${isOwn ? "pb-chat-msg--own" : "pb-chat-msg--other"}">
            <div class="pb-chat-msg-bubble">${escapeHtml(msg.body)}</div>
            <div class="pb-chat-msg-meta">
              ${isOwn ? "" : `<span class="pb-chat-msg-sender">${escapeHtml(msg.sender_name)}</span>`}
              <span class="pb-chat-msg-time">${formatTime(msg.inserted_at)}</span>
              ${seenMark}
            </div>
          </div>
        `;
      }).join("");

      const typingHtml = this.renderTypingIndicator(threadId);

      const rightOffset = 220 + (index * 310);

      return `
        <div class="pb-chat-window" style="right: ${rightOffset}px">
          <div class="pb-chat-window-header">
            <span class="pb-chat-window-name">${escapeHtml(win.friendName)}</span>
            <div class="pb-chat-window-actions">
              <button class="pb-chat-window-btn" data-chat-action="minimize-window" data-thread-id="${threadId}" title="Minimize">&minus;</button>
              <button class="pb-chat-window-btn" data-chat-action="close-window" data-thread-id="${threadId}" title="Close">&times;</button>
            </div>
          </div>
          <div class="pb-chat-window-messages" data-messages-thread="${threadId}">
            ${messages}
            ${typingHtml}
          </div>
          <div class="pb-chat-window-input">
            <textarea class="pb-chat-input" data-thread-id="${threadId}" placeholder="Type a message..." rows="1"></textarea>
          </div>
        </div>
      `;
    }).join("");
  }

  renderMinimized(minimizedWindows) {
    if (minimizedWindows.length === 0) return "";

    const tabs = minimizedWindows.map(([threadId, win]) => {
      const badge = win.unread > 0
        ? `<span class="pb-chat-min-badge">${win.unread}</span>`
        : "";

      return `
        <div class="pb-chat-min-tab" data-chat-action="restore-window" data-thread-id="${threadId}" role="button">
          <span class="pb-chat-min-name">${escapeHtml(win.friendName)}</span>
          ${badge}
          <button class="pb-chat-min-close" data-chat-action="close-window" data-thread-id="${threadId}">&times;</button>
        </div>
      `;
    }).join("");

    return `<div class="pb-chat-minimized">${tabs}</div>`;
  }

  renderTypingIndicator(threadId) {
    const typing = this.typingUsers[threadId];
    if (!typing || Object.keys(typing).length === 0) return "";

    return `
      <div class="pb-chat-typing">
        <span class="pb-chat-typing-dots">
          <span></span><span></span><span></span>
        </span>
        <span class="pb-chat-typing-text">typing...</span>
      </div>
    `;
  }

  destroy() {
    if (this.presenceChannel) this.presenceChannel.leave();
    for (const win of Object.values(this.windows)) {
      if (win.channel) win.channel.leave();
    }
    if (this.socket) this.socket.disconnect();
  }
}
