defmodule SunporchWeb.CoreComponents do
  @moduledoc "Reusable UI components for Sunporch"
  use Phoenix.Component
  use Gettext, backend: SunporchWeb.Gettext

  alias Phoenix.LiveView.JS

  # Sidebar box
  attr :title, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def sidebar_box(assigns) do
    ~H"""
    <div class={"sidebar-box #{@class}"}>
      <div class="sidebar-box-header">{@title}</div>
      <div class="sidebar-box-content">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # Profile thumbnail
  attr :user, :map, required: true
  attr :photo_url, :string, default: nil
  attr :size, :integer, default: 50

  def profile_thumbnail(assigns) do
    assigns = assign(assigns, :avatar_src, avatar_src(assigns))

    ~H"""
    <img
      src={@avatar_src}
      alt={@user.display_name}
      class={"avatar avatar-#{@size}"}
      width={@size}
      height={@size}
    />
    """
  end

  # Public helper for layout templates to generate avatar src
  def avatar_src_for(user, size) do
    avatar_src(%{user: user, size: size})
  end

  @avatar_colors ~w(#6d84b4 #7FB685 #D4726A #E8A033 #8b6bb0 #5b9bd5 #c9736e #6aaa5c)

  defp avatar_src(%{photo_url: url}) when is_binary(url) and url != "", do: url

  defp avatar_src(%{user: user, size: size}) do
    initials = extract_initials(user.display_name)
    color = pick_color(user.id)
    font_size = round(size * 0.42)

    svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}">
    <rect width="#{size}" height="#{size}" rx="2" fill="#{color}"/>
    <text x="50%" y="50%" dy=".1em" fill="white" font-family="Lucida Grande,Tahoma,Verdana,sans-serif" font-size="#{font_size}" font-weight="bold" text-anchor="middle" dominant-baseline="central">#{initials}</text>
    </svg>
    """

    "data:image/svg+xml;base64,#{Base.encode64(svg)}"
  end

  defp extract_initials(nil), do: "?"

  defp extract_initials(name) do
    parts = String.split(name, ~r/\s+/, trim: true)

    case parts do
      [first] -> String.upcase(String.first(first))
      [first | rest] -> String.upcase(String.first(first) <> String.first(List.last(rest)))
      _ -> "?"
    end
  end

  defp pick_color(id) when is_binary(id) do
    index = :erlang.phash2(id, length(@avatar_colors))
    Enum.at(@avatar_colors, index)
  end

  defp pick_color(_), do: hd(@avatar_colors)

  # AI detection badge
  attr :status, :string, required: true

  def ai_badge(assigns) do
    {class, icon, label} =
      case assigns.status do
        "approved" -> {"ai-badge-human", "\u2713", "Human"}
        "pending" -> {"ai-badge-pending", "\u00B7", "Checking"}
        "soft_rejected" -> {"ai-badge-review", "\u29D6", "Under Review"}
        "needs_review" -> {"ai-badge-review", "\u29D6", "Under Review"}
        "appealed" -> {"ai-badge-appealed", "\u29D6", "Appeal Pending"}
        _ -> {"ai-badge-pending", "\u00B7", "Checking"}
      end

    assigns = assign(assigns, class: class, icon: icon, label: label)

    ~H"""
    <span class={"ai-badge #{@class}"}>
      <i class="ai-badge-icon">{@icon}</i> {@label}
    </span>
    """
  end

  # Post card
  attr :post, :map, required: true
  attr :current_user_id, :string, required: true
  attr :like_count, :integer, default: 0
  attr :comment_count, :integer, default: 0
  attr :liked, :boolean, default: false
  slot :inner_block

  def post_card(assigns) do
    ~H"""
    <div class="post-card">
      <div class="post-card-header">
        <a href={"/profile/#{@post.author.slug}"}>
          <.profile_thumbnail user={@post.author} size={32} />
        </a>
        <div class="post-card-meta">
          <a href={"/profile/#{@post.author.slug}"} class="post-author">{@post.author.display_name}</a>
          <span :if={@post.author_id != @post.wall_owner_id}>
            <span class="wall-arrow">&#9654;</span> <a href={"/profile/#{@post.wall_owner.slug}"}>{@post.wall_owner.display_name}</a>
          </span>
          <span class="post-time">
            {format_time(@post.inserted_at)}
            <.ai_badge status={@post.ai_detection_status || "pending"} />
          </span>
        </div>
      </div>
      <div :if={@post.body} class="post-card-body">
        {@post.body}
      </div>
      <div :if={@post.photo_url} class="post-photo">
        <img src={@post.photo_url} alt="Post photo" />
      </div>
      <div class="post-card-actions">
        <button phx-click="toggle_like" phx-value-type="wall_post" phx-value-id={@post.id} class={"like-btn #{if @liked, do: "liked"}"}>
          {if @liked, do: "Unlike", else: "Like"}
        </button>
        <span :if={@like_count > 0} class="like-count">
          {@like_count} {if @like_count == 1, do: "like", else: "likes"}
        </span>
        <button phx-click="toggle_comments" phx-value-id={@post.id} class="comment-btn">
          Comment{if @comment_count > 0, do: " (#{@comment_count})"}
        </button>
        <button :if={@current_user_id == @post.author_id || @current_user_id == @post.wall_owner_id}
                phx-click="delete_post" phx-value-id={@post.id}
                data-confirm="Are you sure?"
                class="delete-btn">
          Delete
        </button>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # Tab bar
  attr :tabs, :list, required: true
  attr :active, :atom, required: true

  def tab_bar(assigns) do
    ~H"""
    <div class="tab-bar">
      <a :for={tab <- @tabs}
         href={tab.href}
         class={"tab #{if tab.id == @active, do: "active"}"}>
        {tab.label}
      </a>
    </div>
    """
  end

  # Pagination
  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :base_url, :string, required: true

  def pagination(assigns) do
    ~H"""
    <div :if={@total_pages > 1} class="pagination">
      <a :if={@page > 1} href={"#{@base_url}?page=#{@page - 1}"} class="page-link">&laquo; Prev</a>
      <span :for={p <- max(1, @page - 3)..min(@total_pages, @page + 3)//1}>
        <a href={"#{@base_url}?page=#{p}"} class={"page-link #{if p == @page, do: "active"}"}>{p}</a>
      </span>
      <a :if={@page < @total_pages} href={"#{@base_url}?page=#{@page + 1}"} class="page-link">Next &raquo;</a>
    </div>
    """
  end

  # Notification badge
  attr :count, :integer, required: true

  def notification_badge(assigns) do
    ~H"""
    <span :if={@count > 0} class="badge">
      {if @count > 99, do: "99+", else: @count}
    </span>
    """
  end

  # Confirm modal
  attr :id, :string, required: true
  attr :message, :string, required: true
  attr :confirm_event, :string, required: true
  attr :confirm_value, :map, default: %{}
  slot :inner_block

  def confirm_modal(assigns) do
    ~H"""
    <div id={@id} class="confirm-overlay" phx-click="close_confirm_modal" phx-key="Escape" phx-window-keydown="close_confirm_modal">
      <div class="confirm-modal" phx-click-away="close_confirm_modal">
        <div class="confirm-modal-body">
          {@message}
        </div>
        <div class="confirm-modal-actions">
          <button phx-click="close_confirm_modal" class="btn btn-gray">Cancel</button>
          <button phx-click={@confirm_event} {assigns_to_attributes(@confirm_value, [])} class="btn btn-blue">Confirm</button>
        </div>
      </div>
    </div>
    """
  end

  # Time formatting helper
  def format_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604_800 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
    end
  end

  # Alert flash components
  attr :flash, :map, required: true
  attr :kind, :atom, required: true
  slot :inner_block

  def flash_message(assigns) do
    ~H"""
    <div :if={msg = Phoenix.Flash.get(@flash, @kind)} class={"alert alert-#{@kind}"}>
      <button type="button" class="alert-close" phx-click={JS.push("lv:clear-flash", value: %{key: @kind})}>&times;</button>
      {msg}
    </div>
    """
  end
end
