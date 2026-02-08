defmodule ParkBenchWeb.FeedLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.{Timeline, Social, AIDetection, Uploader}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    feed = Timeline.get_news_feed(user.id, page: 1)
    feed_counts = precompute_feed_counts(feed, user.id)
    status = Timeline.get_latest_status(user.id)
    pymk = Social.people_you_may_know(user.id, 6)
    pulse = AIDetection.public_stats()

    sent_request_ids =
      Social.list_sent_requests(user.id) |> Enum.map(& &1.receiver.id) |> MapSet.new()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(ParkBench.PubSub, "feed:#{user.id}")
    end

    {:ok,
     socket
     |> assign(:page_title, "News Feed")
     |> assign(:feed, feed)
     |> assign(:feed_counts, feed_counts)
     |> assign(:page, 1)
     |> assign(:status, status)
     |> assign(:pymk, pymk)
     |> assign(:pulse, pulse)
     |> assign(:sent_request_ids, sent_request_ids)
     |> assign(:new_post_body, "")
     |> assign(:status_body, "")
     |> assign(:new_posts_available, false)
     |> assign(:loading_more, false)
     |> assign(:expanded_comments, MapSet.new())
     |> assign(:comments, %{})
     |> allow_upload(:post_photo,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_event("submit_post", %{"body" => body}, socket) do
    user = socket.assigns.current_user

    photo_url =
      case uploaded_entries(socket, :post_photo) do
        {[entry], []} -> Uploader.save_post_photo(entry, socket)
        _ -> nil
      end

    attrs = %{
      author_id: user.id,
      wall_owner_id: user.id,
      body: body
    }

    attrs = if photo_url, do: Map.put(attrs, :photo_url, photo_url), else: attrs

    case Timeline.create_wall_post(attrs) do
      {:ok, _post} ->
        feed = Timeline.get_news_feed(user.id, page: 1)

        {:noreply,
         assign(socket,
           feed: feed,
           feed_counts: precompute_feed_counts(feed, user.id),
           new_post_body: ""
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not create post.")}
    end
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :post_photo, ref)}
  end

  def handle_event("update_status", %{"body" => body}, socket) do
    user = socket.assigns.current_user

    case Timeline.create_status_update(%{user_id: user.id, body: body}) do
      {:ok, status} ->
        {:noreply, assign(socket, status: status, status_body: "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update status.")}
    end
  end

  def handle_event("toggle_like", %{"type" => type, "id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    Timeline.toggle_like(user_id, type, id)
    feed = Timeline.get_news_feed(user_id, page: socket.assigns.page)
    {:noreply, assign(socket, feed: feed, feed_counts: precompute_feed_counts(feed, user_id))}
  end

  def handle_event("delete_post", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    Timeline.soft_delete_post(id, user_id)
    feed = Timeline.get_news_feed(user_id, page: socket.assigns.page)
    {:noreply, assign(socket, feed: feed, feed_counts: precompute_feed_counts(feed, user_id))}
  end

  def handle_event("load_more", _, socket) do
    if socket.assigns.loading_more do
      {:noreply, socket}
    else
      user_id = socket.assigns.current_user.id
      next_page = socket.assigns.page + 1
      more = Timeline.get_news_feed(user_id, page: next_page)
      combined_feed = socket.assigns.feed ++ more

      {:noreply,
       assign(socket,
         feed: combined_feed,
         feed_counts: precompute_feed_counts(combined_feed, user_id),
         page: next_page,
         loading_more: false
       )}
    end
  end

  def handle_event("refresh_feed", _, socket) do
    user_id = socket.assigns.current_user.id
    feed = Timeline.get_news_feed(user_id, page: 1)

    {:noreply,
     assign(socket,
       feed: feed,
       feed_counts: precompute_feed_counts(feed, user_id),
       page: 1,
       new_posts_available: false
     )}
  end

  def handle_event("toggle_comments", %{"id" => post_id}, socket) do
    expanded = socket.assigns.expanded_comments

    if MapSet.member?(expanded, post_id) do
      {:noreply, assign(socket, :expanded_comments, MapSet.delete(expanded, post_id))}
    else
      comments = load_comments(socket.assigns.comments, post_id)

      {:noreply,
       socket
       |> assign(:expanded_comments, MapSet.put(expanded, post_id))
       |> assign(:comments, comments)}
    end
  end

  def handle_event("submit_comment", %{"body" => body, "post-id" => post_id}, socket) do
    user = socket.assigns.current_user

    case Timeline.create_comment(%{
           author_id: user.id,
           commentable_type: "WallPost",
           commentable_id: post_id,
           body: body
         }) do
      {:ok, _comment} ->
        comments = reload_comments(socket.assigns.comments, post_id)
        feed = Timeline.get_news_feed(user.id, page: socket.assigns.page)

        {:noreply,
         socket
         |> assign(:comments, comments)
         |> assign(:feed, feed)
         |> assign(:feed_counts, precompute_feed_counts(feed, user.id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not post comment.")}
    end
  end

  def handle_event("delete_comment", %{"id" => comment_id, "post-id" => post_id}, socket) do
    user_id = socket.assigns.current_user.id
    Timeline.soft_delete_comment(comment_id, user_id)
    comments = reload_comments(socket.assigns.comments, post_id)
    feed = Timeline.get_news_feed(user_id, page: socket.assigns.page)

    {:noreply,
     socket
     |> assign(:comments, comments)
     |> assign(:feed, feed)
     |> assign(:feed_counts, precompute_feed_counts(feed, user_id))}
  end

  def handle_event("send_friend_request", %{"id" => user_id}, socket) do
    case Social.send_friend_request(socket.assigns.current_user.id, user_id) do
      {:ok, _} ->
        {:noreply,
         assign(socket, :sent_request_ids, MapSet.put(socket.assigns.sent_request_ids, user_id))}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("poke_back", %{"id" => poker_id}, socket) do
    Social.poke_back(socket.assigns.current_user.id, poker_id)
    pokes = Social.list_pending_pokes(socket.assigns.current_user.id)
    {:noreply, assign(socket, pending_pokes: pokes)}
  end

  defp precompute_feed_counts(feed, user_id) do
    post_ids =
      for %{feed_item: %{item_type: "wall_post"}, content: c} when c != nil <- feed, do: c.id

    %{
      like_counts: Timeline.batch_like_counts("wall_post", post_ids),
      comment_counts: Timeline.batch_comment_counts("WallPost", post_ids),
      liked_ids: Timeline.batch_liked_ids(user_id, "wall_post", post_ids)
    }
  end

  defp load_comments(comments_map, post_id) do
    if Map.has_key?(comments_map, post_id) do
      comments_map
    else
      reload_comments(comments_map, post_id)
    end
  end

  defp reload_comments(comments_map, post_id) do
    Map.put(comments_map, post_id, Timeline.list_comments("WallPost", post_id))
  end

  @impl true
  def handle_info({:new_feed_item, _}, socket) do
    {:noreply, assign(socket, :new_posts_available, true)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="two-column-right">
      <section class="col-main">
        <div class="feed-filter-bar">
          <h2>News Feed</h2>
        </div>

        <div class="post-composer">
          <div class="post-composer-header">What's on your mind?</div>
          <div class="post-composer-body">
            <form phx-submit="submit_post" phx-change="validate_upload">
              <textarea
                class="form-textarea"
                name="body"
                placeholder="Write something..."
                rows="3"
                maxlength="5000"
              >{@new_post_body}</textarea>
              <div class="post-composer-footer">
                <label class="photo-attach-btn">
                  Attach Photo <.live_file_input upload={@uploads.post_photo} class="sr-only" />
                </label>
                <button type="submit" class="btn btn-blue">Share</button>
              </div>
              <div :for={entry <- @uploads.post_photo.entries} class="post-composer-photo-preview">
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
        </div>

        <div :if={@new_posts_available} class="new-posts-bar" phx-click="refresh_feed">
          New posts available — click to refresh
        </div>

        <div :if={@feed == []} class="empty-state">
          <div class="empty-state-icon">&#x2600;</div>
          <div class="empty-state-title">Welcome to ParkBench!</div>
          <div class="empty-state-text">
            Your news feed is empty. Find some friends to get started!
          </div>
          <a href="/search" class="btn btn-blue">Find Friends</a>
        </div>

        <div id="feed-posts" phx-hook="PhotoLightbox">
          <div :for={%{feed_item: item, content: content} <- @feed} class="feed-entry">
            <div :if={item.item_type == "wall_post" && content}>
              <.post_card
                post={content}
                current_user_id={@current_user.id}
                like_count={Map.get(@feed_counts.like_counts, content.id, 0)}
                comment_count={Map.get(@feed_counts.comment_counts, content.id, 0)}
                liked={MapSet.member?(@feed_counts.liked_ids, content.id)}
              >
                <div :if={MapSet.member?(@expanded_comments, content.id)} class="wall-comments">
                  <div :for={comment <- Map.get(@comments, content.id, [])} class="wall-comment">
                    <div class="wall-comment-content">
                      <a href={~p"/profile/#{comment.author.slug}"} class="wall-comment-author">
                        {comment.author.display_name}
                      </a>
                      <span class="wall-comment-text">{comment.body}</span>
                      <span class="ai-badge-inline">
                        <.ai_badge status={comment.ai_detection_status || "pending"} />
                      </span>
                      <div class="wall-comment-meta">
                        <span class="wall-comment-time">{format_time(comment.inserted_at)}</span>
                        <button
                          :if={
                            @current_user.id == comment.author_id ||
                              @current_user.id == content.author_id ||
                              @current_user.id == content.wall_owner_id
                          }
                          phx-click="delete_comment"
                          phx-value-id={comment.id}
                          phx-value-post-id={content.id}
                          data-confirm="Delete this comment?"
                          class="wall-post-action delete"
                        >
                          Delete
                        </button>
                      </div>
                    </div>
                  </div>
                  <div
                    class="wall-comment-form"
                    phx-hook="CommentSubmitOnEnter"
                    id={"comment-form-#{content.id}"}
                  >
                    <form phx-submit="submit_comment">
                      <input type="hidden" name="post-id" value={content.id} />
                      <input
                        type="text"
                        name="body"
                        placeholder="Write a comment..."
                        maxlength="2000"
                        class="wall-comment-input"
                      />
                      <button type="submit" class="btn btn-small btn-blue">Post</button>
                    </form>
                  </div>
                </div>
              </.post_card>
            </div>
            <div :if={item.item_type == "status_update" && content} class="post-card status-card">
              <div class="post-card-header">
                <a href={"/profile/#{item.user.slug}"}>
                  <.profile_thumbnail user={item.user} size={32} />
                </a>
                <div class="post-card-meta">
                  <a href={"/profile/#{item.user.slug}"} class="post-author">
                    {item.user.display_name}
                  </a>
                  <span class="status-text-inline">{" is #{content.body}"}</span>
                  <span class="post-time">{format_time(item.inserted_at)}</span>
                </div>
              </div>
            </div>
            <div :if={item.item_type == "new_friendship" && content} class="post-card friendship-card">
              <div class="post-card-header">
                <a href={"/profile/#{item.user.slug}"}>
                  <.profile_thumbnail user={item.user} size={32} />
                </a>
                <div class="post-card-meta">
                  <a href={"/profile/#{item.user.slug}"} class="post-author">
                    {item.user.display_name}
                  </a>
                  <span> is now friends with </span>
                  <a href={"/profile/#{content.slug}"} class="post-author">{content.display_name}</a>
                  <span class="post-time">{format_time(item.inserted_at)}</span>
                </div>
              </div>
            </div>
            <div
              :if={item.item_type == "profile_photo_updated" && content}
              class="post-card photo-update-card"
            >
              <div class="post-card-header">
                <a href={"/profile/#{item.user.slug}"}>
                  <.profile_thumbnail user={item.user} size={32} />
                </a>
                <div class="post-card-meta">
                  <a href={"/profile/#{item.user.slug}"} class="post-author">
                    {item.user.display_name}
                  </a>
                  <span> updated their profile picture.</span>
                  <span class="post-time">{format_time(item.inserted_at)}</span>
                </div>
              </div>
              <div class="photo-update-image">
                <a href={"/profile/#{item.user.slug}"}>
                  <img
                    src={content.thumb_200_url || content.original_url}
                    alt="New profile photo"
                    class="feed-profile-photo"
                  />
                </a>
              </div>
            </div>
            <div
              :if={item.item_type == "profile_updated" && content}
              class="post-card photo-update-card"
            >
              <div class="post-card-header">
                <a href={"/profile/#{item.user.slug}"}>
                  <.profile_thumbnail user={item.user} size={32} />
                </a>
                <div class="post-card-meta">
                  <a href={"/profile/#{item.user.slug}"} class="post-author">
                    {item.user.display_name}
                  </a>
                  <span> updated their cover photo.</span>
                  <span class="post-time">{format_time(item.inserted_at)}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@feed != []} class="load-more">
          <div id="infinite-scroll-sentinel" phx-hook="InfiniteScroll"></div>
          <button phx-click="load_more" class="btn btn-gray">Show Older Posts</button>
        </div>
      </section>

      <aside class="col-right">
        <.sidebar_box title="Community Pulse">
          <div class="community-pulse-stat">
            <span class="community-pulse-label">Posts verified</span>
            <span class="community-pulse-value">{@pulse.approved}</span>
          </div>
          <div class="community-pulse-stat">
            <span class="community-pulse-label">Human content</span>
            <span class="community-pulse-value">{@pulse.human_percentage}%</span>
          </div>
          <div class="community-pulse-stat">
            <span class="community-pulse-label">Items flagged</span>
            <span class="community-pulse-value" style="color: var(--sp-status-review)">
              {@pulse.rejected}
            </span>
          </div>
        </.sidebar_box>

        <.sidebar_box title="Status">
          <p :if={@status} class="status-text">
            {@current_user.display_name} is {@status.body}
          </p>
          <form phx-submit="update_status">
            <input
              type="text"
              name="body"
              value={@status_body}
              placeholder="What are you doing right now?"
              maxlength="160"
              class="status-input"
            />
            <button type="submit" class="btn btn-small btn-blue">Update</button>
          </form>
        </.sidebar_box>

        <.sidebar_box :if={@pending_pokes != []} title="Pokes">
          <div :for={%{poker: poker} <- @pending_pokes} class="poke-item">
            <.profile_thumbnail user={poker} size={20} />
            <span><strong>{poker.display_name}</strong> poked you.</span>
            <button phx-click="poke_back" phx-value-id={poker.id} class="btn btn-small btn-blue">
              Poke Back
            </button>
          </div>
        </.sidebar_box>

        <.sidebar_box :if={@pymk != []} title="People You May Know">
          <div :for={%{user: suggestion, mutual_count: count} <- @pymk} class="pymk-item">
            <a href={"/profile/#{suggestion.slug}"}>
              <.profile_thumbnail user={suggestion} size={32} />
            </a>
            <div class="pymk-details">
              <a href={"/profile/#{suggestion.slug}"}>{suggestion.display_name}</a>
              <span class="mutual-count">{count} mutual friend{if count != 1, do: "s"}</span>
            </div>
            <button
              :if={!MapSet.member?(@sent_request_ids, suggestion.id)}
              phx-click="send_friend_request"
              phx-value-id={suggestion.id}
              class="btn btn-small btn-blue pymk-add-btn"
            >
              Add Friend
            </button>
            <span :if={MapSet.member?(@sent_request_ids, suggestion.id)} class="pymk-requested">
              Requested
            </span>
          </div>
        </.sidebar_box>
      </aside>
    </div>
    """
  end
end
