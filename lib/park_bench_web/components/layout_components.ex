defmodule ParkBenchWeb.LayoutComponents do
  @moduledoc "Layout components: top nav, left sidebar, profile card, nav menu"
  use Phoenix.Component
  import ParkBenchWeb.CoreComponents, only: [profile_thumbnail: 1]

  attr :current_user, :map, required: true
  attr :pending_friend_requests, :integer, default: 0
  attr :unread_messages, :integer, default: 0
  attr :unread_notifications, :integer, default: 0

  def top_nav(assigns) do
    ~H"""
    <nav class="top-nav">
      <div class="top-nav-inner">
        <a href="/feed" class="logo-link">
          <svg
            class="logo-icon"
            viewBox="0 0 32 32"
            xmlns="http://www.w3.org/2000/svg"
            aria-hidden="true"
          >
            <rect x="4" y="14" width="24" height="3" rx="1.5" fill="currentColor" />
            <rect x="6" y="8" width="20" height="2" rx="1" fill="currentColor" opacity="0.7" />
            <rect x="6" y="11" width="20" height="2" rx="1" fill="currentColor" opacity="0.7" />
            <g stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
              <line x1="7" y1="17" x2="7" y2="25" /><line x1="25" y1="17" x2="25" y2="25" />
            </g>
            <rect x="4" y="8" width="2.5" height="9" rx="1.25" fill="currentColor" />
            <rect x="25.5" y="8" width="2.5" height="9" rx="1.25" fill="currentColor" />
            <circle cx="10" cy="6" r="2.5" fill="currentColor" opacity="0.15" />
            <circle cx="22" cy="5" r="3" fill="currentColor" opacity="0.12" />
            <circle cx="16" cy="4" r="2" fill="currentColor" opacity="0.1" />
          </svg>
          <span class="logo-text">Park<span style="color: var(--moss)">Bench</span></span>
        </a>

        <div class="search-bar">
          <svg
            class="search-icon"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <circle cx="10.5" cy="10.5" r="6.5" /><line x1="15" y1="15" x2="21" y2="21" />
          </svg>
          <form action="/search" method="get">
            <input
              type="text"
              name="q"
              placeholder="Search ParkBench..."
              class="search-input"
              autocomplete="off"
            />
          </form>
        </div>

        <div class="nav-actions">
          <a href="/notifications" class="nav-btn" title="Notifications">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
              <path d="M13.73 21a2 2 0 0 1-3.46 0" />
            </svg>
            <span :if={@unread_notifications > 0} class="nav-btn-badge">{@unread_notifications}</span>
          </a>
          <a href="/inbox" class="nav-btn" title="Messages">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
            </svg>
            <span :if={@unread_messages > 0} class="nav-btn-badge">{@unread_messages}</span>
          </a>
          <a href="/friends/requests" class="nav-btn" title="Friends">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
              <circle cx="9" cy="7" r="4" />
              <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
              <path d="M16 3.13a4 4 0 0 1 0 7.75" />
            </svg>
            <span :if={@pending_friend_requests > 0} class="nav-btn-badge">
              {@pending_friend_requests}
            </span>
          </a>
          <a href={"/profile/#{@current_user.slug}"} class="avatar-btn" title="Profile">
            <.profile_thumbnail user={@current_user} size={36} />
          </a>
        </div>
      </div>
    </nav>
    """
  end

  attr :current_user, :map, required: true
  attr :bench_streak, :integer, default: 0
  attr :friend_count, :integer, default: 0

  def profile_card(assigns) do
    ~H"""
    <div class="profile-card">
      <a href={"/profile/#{@current_user.slug}"}>
        <.profile_thumbnail user={@current_user} size={72} class="profile-avatar" />
      </a>
      <div class="profile-name">{@current_user.display_name}</div>
      <div class="profile-handle">@{@current_user.slug}</div>
      <div :if={@bench_streak > 0} class="bench-streak">
        🔥 {@bench_streak}-day bench streak
      </div>
    </div>
    """
  end

  attr :nav_active, :atom, default: nil
  attr :pending_friend_requests, :integer, default: 0
  attr :unread_messages, :integer, default: 0

  def nav_menu(assigns) do
    ~H"""
    <nav class="nav-menu">
      <div class="nav-section-title">Share</div>
      <a href="/feed" class={"nav-item #{if @nav_active == :feed, do: "active"}"}>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" /><polyline points="9 22 9 12 15 12 15 22" />
        </svg>
        Show & Tell
      </a>
      <a href="/feed?tab=journals" class={"nav-item #{if @nav_active == :journals, do: "active"}"}>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" /><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
        </svg>
        My Journal
      </a>

      <div class="nav-section-title">Wellness</div>
      <a href="/feed?tab=wellness" class={"nav-item #{if @nav_active == :wellness, do: "active"}"}>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
        </svg>
        Health & Steps
      </a>

      <div class="nav-section-title">Park Life</div>
      <a href="/feed?tab=paw_prints" class={"nav-item #{if @nav_active == :paw_prints, do: "active"}"}>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <circle cx="12" cy="12" r="10" /><line x1="2" y1="12" x2="22" y2="12" /><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
        </svg>
        Paw Prints 🐾
      </a>
      <a href="/feed?tab=playground" class={"nav-item #{if @nav_active == :playground, do: "active"}"}>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <circle cx="12" cy="12" r="10" /><path d="M8 14s1.5 2 4 2 4-2 4-2" /><line
            x1="9"
            y1="9"
            x2="9.01"
            y2="9"
          /><line x1="15" y1="9" x2="15.01" y2="9" />
        </svg>
        Playground
      </a>

      <div class="nav-section-title">Connect</div>
      <a href="/friends/requests" class={"nav-item #{if @nav_active == :friends, do: "active"}"}>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
        Bench Buddies
        <span :if={@pending_friend_requests > 0} class="count">{@pending_friend_requests}</span>
      </a>
      <a href="/inbox" class={"nav-item #{if @nav_active == :inbox, do: "active"}"}>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        </svg>
        Messages <span :if={@unread_messages > 0} class="count">{@unread_messages}</span>
      </a>
    </nav>

    <button class="compose-btn" onclick="window.location.href='/feed'">
      <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        style="width:18px;height:18px"
      >
        <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
      </svg>
      Share Something
    </button>
    """
  end
end
