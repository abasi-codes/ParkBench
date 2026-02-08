defmodule ParkBenchWeb.FeedComponents do
  @moduledoc "Feed post cards, tabs, and composer for the redesigned feed"
  use Phoenix.Component
  import ParkBenchWeb.CoreComponents, only: [profile_thumbnail: 1, ai_badge: 1, format_time: 1]

  # ── Feed Tabs ──────────────────────────────────────────────────────────

  attr :active_tab, :string, default: "all"

  def feed_tabs(assigns) do
    ~H"""
    <div class="feed-tabs">
      <button
        :for={
          {tab_id, label, icon} <- [
            {"all", "All", "🏡"},
            {"story", "Stories", "📖"},
            {"journal", "Journals", "✏️"},
            {"wellness", "Wellness", "❤️"},
            {"pet", "Paw Prints", "🐾"},
            {"playground", "Playground", "🎠"}
          ]
        }
        phx-click="change_tab"
        phx-value-tab={tab_id}
        class={"feed-tab #{if @active_tab == tab_id, do: "active"}"}
      >
        <span class="feed-tab-icon">{icon}</span>
        <span class="feed-tab-label">{label}</span>
      </button>
    </div>
    """
  end

  # ── Post Composer ──────────────────────────────────────────────────────

  attr :current_user, :map, required: true
  attr :post_type, :string, default: "story"
  attr :uploads, :map, required: true

  def post_composer(assigns) do
    ~H"""
    <div class="story-card post-composer-card">
      <div class="story-header">
        <.profile_thumbnail user={@current_user} size={44} />
        <div class="composer-prompt">
          <div class="composer-greeting">
            What's happening at the park, {@current_user.display_name}?
          </div>
          <div class="composer-type-pills">
            <button
              :for={
                {type, label, icon} <- [
                  {"story", "Story", "📖"},
                  {"journal", "Journal", "✏️"},
                  {"wellness", "Wellness", "❤️"},
                  {"pet", "Paw Print", "🐾"},
                  {"playground", "Playground", "🎠"}
                ]
              }
              phx-click="change_post_type"
              phx-value-type={type}
              class={"type-pill #{if @post_type == type, do: "active"}"}
            >
              {icon} {label}
            </button>
          </div>
        </div>
      </div>
      <form phx-submit="submit_post" phx-change="validate_upload" class="composer-form">
        <input type="hidden" name="post_type" value={@post_type} />
        <textarea
          class="composer-textarea"
          name="body"
          placeholder={composer_placeholder(@post_type)}
          rows="3"
          maxlength="5000"
        ></textarea>
        <div :if={@post_type == "journal"} class="composer-mood-row">
          <label class="mood-label">Mood:</label>
          <select name="mood" class="mood-select">
            <option value="">Select mood...</option>
            <option
              :for={
                mood <- ~w(grateful peaceful reflective hopeful energetic cozy adventurous nostalgic)
              }
              value={mood}
            >
              {String.capitalize(mood)}
            </option>
          </select>
        </div>
        <div class="composer-footer">
          <label class="photo-attach-btn">
            📷 Photo <.live_file_input upload={@uploads.post_photo} class="sr-only" />
          </label>
          <button type="submit" class="composer-submit-btn">Share on the Bench</button>
        </div>
        <div :for={entry <- @uploads.post_photo.entries} class="composer-photo-preview">
          <.live_img_preview entry={entry} class="composer-preview-img" />
          <button
            type="button"
            phx-click="cancel_upload"
            phx-value-ref={entry.ref}
            class="upload-cancel"
          >
            &times;
          </button>
        </div>
      </form>
    </div>
    """
  end

  # ── Story Card (polymorphic post renderer) ─────────────────────────────

  attr :post, :map, required: true
  attr :current_user_id, :string, required: true
  attr :like_count, :integer, default: 0
  attr :comment_count, :integer, default: 0
  attr :liked, :boolean, default: false
  attr :bookmarked, :boolean, default: false
  attr :share_count, :integer, default: 0
  slot :inner_block

  def story_card(assigns) do
    ~H"""
    <div class={"story-card #{post_type_class(@post.post_type)}"}>
      <div class="story-header">
        <a href={"/profile/#{@post.author.slug}"}>
          <.profile_thumbnail user={@post.author} size={44} />
        </a>
        <div class="story-meta">
          <div class="story-author-row">
            <a href={"/profile/#{@post.author.slug}"} class="story-author">
              {@post.author.display_name}
            </a>
            <span :if={@post.author_id != @post.wall_owner_id} class="story-wall-arrow">
              ▸ <a href={"/profile/#{@post.wall_owner.slug}"}>{@post.wall_owner.display_name}</a>
            </span>
          </div>
          <div class="story-time-row">
            <span class="story-time">{format_time(@post.inserted_at)}</span>
            <span class="story-type-badge">{post_type_badge(@post.post_type)}</span>
            <.ai_badge status={@post.ai_detection_status || "pending"} />
          </div>
        </div>
      </div>

      <%= case @post.post_type do %>
        <% "journal" -> %>
          <.journal_body post={@post} />
        <% "wellness" -> %>
          <.wellness_body post={@post} />
        <% "pet" -> %>
          <.pet_body post={@post} />
        <% "playground" -> %>
          <.playground_body post={@post} />
        <% _ -> %>
          <.story_body post={@post} />
      <% end %>

      <div class="story-actions">
        <button
          phx-click="toggle_like"
          phx-value-type="wall_post"
          phx-value-id={@post.id}
          class={"story-action-btn #{if @liked, do: "liked"}"}
        >
          <svg
            viewBox="0 0 24 24"
            fill={if @liked, do: "var(--sunset)", else: "none"}
            stroke={if @liked, do: "var(--sunset)", else: "currentColor"}
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="action-icon"
          >
            <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
          </svg>
          <span :if={@like_count > 0} class="action-count">{@like_count}</span>
        </button>
        <button phx-click="toggle_comments" phx-value-id={@post.id} class="story-action-btn">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="action-icon"
          >
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
          </svg>
          <span :if={@comment_count > 0} class="action-count">{@comment_count}</span>
        </button>
        <button phx-click="share" phx-value-id={@post.id} class="story-action-btn">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="action-icon"
          >
            <circle cx="18" cy="5" r="3" /><circle cx="6" cy="12" r="3" /><circle
              cx="18"
              cy="19"
              r="3"
            /><line x1="8.59" y1="13.51" x2="15.42" y2="17.49" /><line
              x1="15.41"
              y1="6.51"
              x2="8.59"
              y2="10.49"
            />
          </svg>
          <span :if={@share_count > 0} class="action-count">{@share_count}</span>
        </button>
        <button
          phx-click={if @bookmarked, do: "unbookmark", else: "bookmark"}
          phx-value-id={@post.id}
          class={"story-action-btn bookmark-btn #{if @bookmarked, do: "bookmarked"}"}
        >
          <svg
            viewBox="0 0 24 24"
            fill={if @bookmarked, do: "var(--golden)", else: "none"}
            stroke={if @bookmarked, do: "var(--golden)", else: "currentColor"}
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="action-icon"
          >
            <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
          </svg>
        </button>
        <button
          :if={@current_user_id == @post.author_id || @current_user_id == @post.wall_owner_id}
          phx-click="delete_post"
          phx-value-id={@post.id}
          data-confirm="Are you sure?"
          class="story-action-btn delete-btn"
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="action-icon"
          >
            <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
          </svg>
        </button>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ── Post Type Sub-Components ───────────────────────────────────────────

  attr :post, :map, required: true

  defp story_body(assigns) do
    ~H"""
    <div :if={@post.body} class="story-content">{@post.body}</div>
    <div :if={@post.photo_url} class="story-media">
      <img src={@post.photo_url} alt="Post photo" class="story-photo" />
    </div>
    """
  end

  attr :post, :map, required: true

  defp journal_body(assigns) do
    ~H"""
    <div class="journal-entry">
      <div :if={@post.mood} class="journal-mood-badge">
        {mood_emoji(@post.mood)} {String.capitalize(@post.mood)}
      </div>
      <div class="journal-text">{@post.body}</div>
      <div :if={@post.photo_url} class="story-media">
        <img src={@post.photo_url} alt="Journal photo" class="story-photo" />
      </div>
    </div>
    """
  end

  attr :post, :map, required: true

  defp wellness_body(assigns) do
    post = assigns.post
    embed = if Ecto.assoc_loaded?(post.wellness_embed), do: post.wellness_embed, else: nil
    assigns = assign(assigns, :embed, embed)

    ~H"""
    <div class="wellness-card-body">
      <div :if={@post.body} class="story-content">{@post.body}</div>
      <div :if={@embed} class="wellness-stats-grid">
        <div :if={@embed.steps} class="wellness-stat">
          <div class="wellness-stat-icon">👟</div>
          <div class="wellness-stat-value">{@embed.steps}</div>
          <div class="wellness-stat-label">Steps</div>
        </div>
        <div :if={@embed.heart_rate_bpm} class="wellness-stat">
          <div class="wellness-stat-icon">❤️</div>
          <div class="wellness-stat-value">{@embed.heart_rate_bpm}</div>
          <div class="wellness-stat-label">BPM</div>
        </div>
        <div :if={@embed.calories} class="wellness-stat">
          <div class="wellness-stat-icon">🔥</div>
          <div class="wellness-stat-value">{@embed.calories}</div>
          <div class="wellness-stat-label">Cal</div>
        </div>
        <div :if={@embed.distance_km} class="wellness-stat">
          <div class="wellness-stat-icon">🏃</div>
          <div class="wellness-stat-value">{Float.round(@embed.distance_km, 1)}</div>
          <div class="wellness-stat-label">km</div>
        </div>
        <div :if={@embed.sleep_hours} class="wellness-stat">
          <div class="wellness-stat-icon">🌙</div>
          <div class="wellness-stat-value">{@embed.sleep_hours}h</div>
          <div class="wellness-stat-label">Sleep</div>
        </div>
      </div>
      <div :if={@post.photo_url} class="story-media">
        <img src={@post.photo_url} alt="Wellness photo" class="story-photo" />
      </div>
    </div>
    """
  end

  attr :post, :map, required: true

  defp pet_body(assigns) do
    post = assigns.post

    embeds =
      if Ecto.assoc_loaded?(post.pet_embeds), do: post.pet_embeds, else: []

    assigns = assign(assigns, :pet_embeds, embeds)

    ~H"""
    <div class="pet-post-body">
      <div :if={@post.body} class="story-content">{@post.body}</div>
      <div :for={pe <- @pet_embeds} class="pet-embed-card">
        <span class="pet-embed-emoji">{if pe.pet, do: pe.pet.emoji, else: "🐾"}</span>
        <span class="pet-embed-name">{if pe.pet, do: pe.pet.name, else: "Pet"}</span>
        <span :if={pe.activity_note} class="pet-embed-note">— {pe.activity_note}</span>
      </div>
      <div :if={@post.photo_url} class="story-media">
        <img src={@post.photo_url} alt="Pet photo" class="story-photo" />
      </div>
    </div>
    """
  end

  attr :post, :map, required: true

  defp playground_body(assigns) do
    post = assigns.post

    embeds =
      if Ecto.assoc_loaded?(post.kid_embeds), do: post.kid_embeds, else: []

    assigns = assign(assigns, :kid_embeds, embeds)

    ~H"""
    <div class="playground-post-body">
      <div :if={@post.body} class="story-content">{@post.body}</div>
      <div :for={ke <- @kid_embeds} class="kid-embed-card">
        <span class="kid-embed-emoji">{if ke.kid, do: ke.kid.emoji, else: "👶"}</span>
        <span class="kid-embed-name">{if ke.kid, do: ke.kid.name, else: "Child"}</span>
        <div :if={ke.milestone_text} class="kid-milestone">🌟 {ke.milestone_text}</div>
        <blockquote :if={ke.quote_text} class="kid-quote">
          "{ke.quote_text}" <cite :if={ke.quote_attribution}>— {ke.quote_attribution}</cite>
        </blockquote>
      </div>
      <div :if={@post.photo_url} class="story-media">
        <img src={@post.photo_url} alt="Playground photo" class="story-photo" />
      </div>
    </div>
    """
  end

  # ── Helpers ────────────────────────────────────────────────────────────

  defp post_type_class("journal"), do: "journal-card"
  defp post_type_class("wellness"), do: "wellness-card"
  defp post_type_class("pet"), do: "pet-card"
  defp post_type_class("playground"), do: "playground-card"
  defp post_type_class(_), do: ""

  defp post_type_badge("story"), do: "📖 Story"
  defp post_type_badge("journal"), do: "✏️ Journal"
  defp post_type_badge("wellness"), do: "❤️ Wellness"
  defp post_type_badge("pet"), do: "🐾 Paw Print"
  defp post_type_badge("playground"), do: "🎠 Playground"
  defp post_type_badge(_), do: ""

  defp mood_emoji("grateful"), do: "🙏"
  defp mood_emoji("peaceful"), do: "☮️"
  defp mood_emoji("reflective"), do: "🪞"
  defp mood_emoji("hopeful"), do: "🌅"
  defp mood_emoji("energetic"), do: "⚡"
  defp mood_emoji("cozy"), do: "☕"
  defp mood_emoji("adventurous"), do: "🧭"
  defp mood_emoji("nostalgic"), do: "📷"
  defp mood_emoji(_), do: "💭"

  defp composer_placeholder("story"), do: "Share what's happening at the park..."
  defp composer_placeholder("journal"), do: "Dear journal, today I..."
  defp composer_placeholder("wellness"), do: "Share your wellness journey..."
  defp composer_placeholder("pet"), do: "What are your park companions up to?"
  defp composer_placeholder("playground"), do: "What are the kids doing today?"
  defp composer_placeholder(_), do: "Write something..."
end
