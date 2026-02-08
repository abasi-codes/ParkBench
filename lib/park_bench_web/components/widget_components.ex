defmodule ParkBenchWeb.WidgetComponents do
  @moduledoc "Right sidebar widget components"
  use Phoenix.Component
  import ParkBenchWeb.CoreComponents, only: [profile_thumbnail: 1]

  attr :pulse, :map, required: true

  def ai_shield_widget(assigns) do
    ~H"""
    <div class="widget ai-shield-widget">
      <div class="widget-title">🛡️ AI Shield</div>
      <div class="shield-stat-row">
        <div class="shield-stat-icon text-check">📝</div>
        <div class="shield-stat-info">
          <div class="shield-stat-label">Text Analysis</div>
          <div class="shield-stat-detail">{@pulse.approved} posts verified</div>
        </div>
        <div class="shield-stat-badge">Active</div>
      </div>
      <div class="shield-stat-row">
        <div class="shield-stat-icon image-check">🖼️</div>
        <div class="shield-stat-info">
          <div class="shield-stat-label">Image Scanning</div>
          <div class="shield-stat-detail">{@pulse.human_percentage}% human content</div>
        </div>
        <div class="shield-stat-badge">Active</div>
      </div>
      <div class="shield-stat-row">
        <div class="shield-stat-icon comment-check">💬</div>
        <div class="shield-stat-info">
          <div class="shield-stat-label">Comment Guard</div>
          <div class="shield-stat-detail">{@pulse.rejected} items flagged</div>
        </div>
        <div class="shield-stat-badge">Active</div>
      </div>
      <div class="shield-community-note">
        <strong>Community trust:</strong>
        Every post, image, and comment is analyzed for AI-generated content.
      </div>
    </div>
    """
  end

  attr :friend_count, :integer, default: 0
  attr :online_count, :integer, default: 0

  def friends_circle_widget(assigns) do
    ~H"""
    <div class="widget friends-circle-widget">
      <div class="widget-title">👋 Friends Circle</div>
      <div class="friends-stats">
        <div class="friends-stat">
          <div class="friends-stat-value">{@friend_count}</div>
          <div class="friends-stat-label">Friends</div>
        </div>
        <div class="friends-stat">
          <div class="friends-stat-value">{@online_count}</div>
          <div class="friends-stat-label">Online</div>
        </div>
        <div class="friends-stat">
          <div class="friends-stat-value">0</div>
          <div class="friends-stat-label">Algorithms</div>
        </div>
      </div>
      <div class="friends-note">
        <strong>No followers.</strong> No strangers. No ads.
      </div>
    </div>
    """
  end

  attr :weather, :map, default: nil

  def weather_widget(assigns) do
    ~H"""
    <div :if={@weather} class="widget nature-widget">
      <div class="nature-info">
        <div>
          <div class="nature-temp">{@weather.temperature}°</div>
          <div class="nature-desc">{@weather.condition}</div>
        </div>
        <div class="nature-detail">
          Sunset: {@weather.sunset}<br />Breeze: {@weather.breeze}<br />Air: {@weather.air} 🌿
        </div>
      </div>
    </div>
    """
  end

  attr :wellness_today, :map, default: nil

  def wellness_overview_widget(assigns) do
    ~H"""
    <div :if={@wellness_today} class="widget">
      <div class="widget-title">⌚ My Wellness Today</div>
      <div class="wellness-overview">
        <div class="wellness-mini-card steps">
          <div class="wellness-mini-icon">👟</div>
          <div class="wellness-mini-value">{@wellness_today.steps || 0}</div>
          <div class="wellness-mini-label">Steps</div>
        </div>
        <div class="wellness-mini-card heart">
          <div class="wellness-mini-icon">❤️</div>
          <div class="wellness-mini-value">{@wellness_today.heart_rate_bpm || 0}</div>
          <div class="wellness-mini-label">Resting BPM</div>
        </div>
        <div class="wellness-mini-card sleep">
          <div class="wellness-mini-icon">🌙</div>
          <div class="wellness-mini-value">{@wellness_today.sleep_hours || 0}h</div>
          <div class="wellness-mini-label">Sleep</div>
        </div>
        <div class="wellness-mini-card mindful">
          <div class="wellness-mini-icon">🧘</div>
          <div class="wellness-mini-value">{@wellness_today.calories || 0}</div>
          <div class="wellness-mini-label">Cal</div>
        </div>
      </div>
    </div>
    """
  end

  attr :pets, :list, default: []

  def pets_widget(assigns) do
    ~H"""
    <div :if={@pets != []} class="widget">
      <div class="widget-title">🐾 My Park Companions</div>
      <div :for={pet <- @pets} class="my-pet-card">
        <div class="my-pet-avatar">{pet.emoji}</div>
        <div>
          <div class="my-pet-name">{pet.name}</div>
          <div class="my-pet-breed">{pet.breed || pet.species} · {pet.age_years || "?"} yrs</div>
          <div :if={pet.mood} class="my-pet-mood">😊 {String.capitalize(pet.mood)}</div>
        </div>
      </div>
      <button class="pet-walk-btn">🐾 Log a Park Walk</button>
    </div>
    """
  end

  attr :kids, :list, default: []

  def playground_widget(assigns) do
    ~H"""
    <div :if={@kids != []} class="widget playground-widget">
      <div class="widget-title" style="color: var(--playground)">🎠 My Playground</div>
      <div :for={kid <- @kids} class="playground-kid-row">
        <div class="playground-kid-avatar">{kid.emoji}</div>
        <div class="playground-kid-info">
          <div class="playground-kid-name">{kid.name}</div>
          <div class="playground-kid-detail">
            {kid.age_years || "?"} yrs{if kid.current_activity, do: " · #{kid.current_activity}"}
          </div>
        </div>
      </div>
      <button class="playground-add-btn">🎠 Add playground update</button>
    </div>
    """
  end

  attr :online_friends, :list, default: []

  def buddy_list(assigns) do
    ~H"""
    <div class="widget" id="buddy-list" phx-hook="BuddyList">
      <div class="widget-title">🪑 At the Bench Now</div>
      <div class="buddy-list">
        <div :for={friend <- @online_friends} class="buddy-item" data-friend-id={friend.id}>
          <div class="buddy-avatar">
            <.profile_thumbnail user={friend} size={36} />
            <span class="online-dot"></span>
          </div>
          <div>
            <div class="buddy-name">{friend.display_name}</div>
          </div>
        </div>
        <div
          :if={@online_friends == []}
          style="font-size: 13px; color: var(--stone); text-align: center; padding: 12px 0;"
        >
          No friends online right now
        </div>
      </div>
    </div>
    """
  end

  attr :trending, :list, default: []

  def trending_widget(assigns) do
    ~H"""
    <div :if={@trending != []} class="widget">
      <div class="widget-title">🔥 Stories Worth Sitting For</div>
      <div :for={post <- @trending} class="trending-item">
        <div class="trending-label">{post_type_label(post.post_type)}</div>
        <div class="trending-title">{truncate(post.body, 80)}</div>
        <div class="trending-engagement">
          <a href={"/profile/#{post.author.slug}"}>{post.author.display_name}</a>
        </div>
      </div>
    </div>
    """
  end

  defp post_type_label("story"), do: "Trending Story"
  defp post_type_label("journal"), do: "Popular Journal"
  defp post_type_label("wellness"), do: "Wellness Highlight"
  defp post_type_label("pet"), do: "Paw Print of the Week"
  defp post_type_label("playground"), do: "Playground Favorite"
  defp post_type_label(_), do: "Trending"

  defp truncate(nil, _), do: ""
  defp truncate(text, max) when byte_size(text) <= max, do: text
  defp truncate(text, max), do: String.slice(text, 0, max) <> "..."
end
