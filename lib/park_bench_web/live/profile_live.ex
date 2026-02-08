defmodule ParkBenchWeb.ProfileLive do
  use ParkBenchWeb, :live_view

  alias ParkBench.{Accounts, Social, Timeline, Privacy, Media, AIDetection, Uploader}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    profile_user = Accounts.get_user_by_slug(slug)
    current_user = socket.assigns.current_user

    if is_nil(profile_user) do
      {:ok, push_navigate(socket, to: "/feed") |> put_flash(:error, "User not found.")}
    else
      relationship = Social.relationship_status(current_user.id, profile_user.id)

      if relationship == :blocked do
        {:ok, push_navigate(socket, to: "/feed") |> put_flash(:error, "User not found.")}
      else
        profile = Accounts.get_profile(profile_user.id)
        privacy = Privacy.get_privacy_settings(profile_user.id)
        photo = Accounts.get_current_profile_photo(profile_user.id)
        friends = Social.list_friends(profile_user.id) |> Enum.take(6)
        friend_count = Social.count_friends(profile_user.id)

        mutual =
          if current_user.id != profile_user.id,
            do: Social.count_mutual_friends(current_user.id, profile_user.id),
            else: 0

        poked =
          if relationship == :friends,
            do: Social.active_poke?(current_user.id, profile_user.id),
            else: false

        own_profile? = current_user.id == profile_user.id

        socket =
          socket
          |> assign(:page_title, profile_user.display_name)
          |> assign(:profile_user, profile_user)
          |> assign(:profile, profile)
          |> assign(:privacy, privacy)
          |> assign(:photo, photo)
          |> assign(:relationship, relationship)
          |> assign(:friends, friends)
          |> assign(:friend_count, friend_count)
          |> assign(:mutual_count, mutual)
          |> assign(:wall_posts, [])
          |> assign(:wall_counts, %{
            like_counts: %{},
            comment_counts: %{},
            liked_ids: MapSet.new()
          })
          |> assign(:new_post_body, "")
          |> assign(:expanded_comments, MapSet.new())
          |> assign(:comments, %{})
          |> assign(:poked, poked)
          |> assign(:albums, [])
          |> assign(:own_profile, own_profile?)
          |> assign(:trusted, compute_trust(profile_user.id))

        socket =
          if own_profile? do
            socket
            |> allow_upload(:profile_photo,
              accept: ~w(.jpg .jpeg .png .gif .webp),
              max_entries: 1,
              max_file_size: 10_000_000
            )
            |> allow_upload(:cover_photo,
              accept: ~w(.jpg .jpeg .png .gif .webp),
              max_entries: 1,
              max_file_size: 10_000_000
            )
            |> allow_upload(:wall_photo,
              accept: ~w(.jpg .jpeg .png .gif .webp),
              max_entries: 1,
              max_file_size: 10_000_000
            )
          else
            socket
            |> allow_upload(:wall_photo,
              accept: ~w(.jpg .jpeg .png .gif .webp),
              max_entries: 1,
              max_file_size: 10_000_000
            )
          end

        {:ok, load_tab_data(socket)}
      end
    end
  end

  defp load_tab_data(socket) do
    case socket.assigns.live_action do
      :wall ->
        posts =
          Timeline.list_wall_posts(socket.assigns.profile_user.id,
            viewer_id: socket.assigns.current_user.id
          )

        wall_counts = precompute_wall_counts(posts, socket.assigns.current_user.id)
        socket |> assign(:wall_posts, posts) |> assign(:wall_counts, wall_counts)

      :info ->
        socket

      :photos ->
        albums = Media.list_albums(socket.assigns.profile_user.id)
        assign(socket, :albums, albums)

      _ ->
        socket
    end
  end

  defp precompute_wall_counts(posts, user_id) do
    post_ids = Enum.map(posts, & &1.id)

    %{
      like_counts: Timeline.batch_like_counts("wall_post", post_ids),
      comment_counts: Timeline.batch_comment_counts("WallPost", post_ids),
      liked_ids: Timeline.batch_liked_ids(user_id, "wall_post", post_ids)
    }
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, load_tab_data(socket)}
  end

  @impl true
  def handle_event("save_profile_photo", _params, socket) do
    user = socket.assigns.current_user

    case uploaded_entries(socket, :profile_photo) do
      {[entry], []} ->
        url = Uploader.save_profile_photo(entry, socket)

        case Accounts.create_profile_photo(user.id, %{original_url: url}) do
          {:ok, new_photo} ->
            {:noreply,
             socket
             |> assign(:photo, new_photo)
             |> put_flash(:info, "Profile photo updated!")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not save profile photo.")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("save_cover_photo", _params, socket) do
    user = socket.assigns.current_user

    case uploaded_entries(socket, :cover_photo) do
      {[entry], []} ->
        url = Uploader.save_cover_photo(entry, socket)

        case Accounts.update_cover_photo(user.id, url) do
          {:ok, profile} ->
            {:noreply,
             socket
             |> assign(:profile, profile)
             |> put_flash(:info, "Cover photo updated!")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not save cover photo.")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref, "upload" => upload_name}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(upload_name), ref)}
  end

  def handle_event("submit_wall_post", %{"body" => body}, socket) do
    user = socket.assigns.current_user
    profile_user = socket.assigns.profile_user

    if Timeline.can_post_on_wall?(user.id, profile_user.id) do
      photo_url =
        case uploaded_entries(socket, :wall_photo) do
          {[entry], []} -> Uploader.save_post_photo(entry, socket)
          _ -> nil
        end

      attrs = %{
        author_id: user.id,
        wall_owner_id: profile_user.id,
        body: body
      }

      attrs = if photo_url, do: Map.put(attrs, :photo_url, photo_url), else: attrs

      case Timeline.create_wall_post(attrs) do
        {:ok, _post} ->
          posts = Timeline.list_wall_posts(profile_user.id, viewer_id: user.id)

          {:noreply,
           assign(socket,
             wall_posts: posts,
             wall_counts: precompute_wall_counts(posts, user.id),
             new_post_body: ""
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not create post.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You cannot post on this wall.")}
    end
  end

  def handle_event("send_poke", _, socket) do
    case Social.poke(socket.assigns.current_user.id, socket.assigns.profile_user.id) do
      {:ok, _} ->
        {:noreply, assign(socket, :poked, true) |> put_flash(:info, "Poked!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not poke.")}
    end
  end

  def handle_event("send_friend_request", _, socket) do
    case Social.send_friend_request(
           socket.assigns.current_user.id,
           socket.assigns.profile_user.id
         ) do
      {:ok, _} ->
        {:noreply,
         assign(socket, :relationship, :request_sent) |> put_flash(:info, "Friend request sent!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not send request: #{reason}")}
    end
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
        posts = Timeline.list_wall_posts(socket.assigns.profile_user.id, viewer_id: user.id)

        {:noreply,
         socket
         |> assign(:comments, comments)
         |> assign(:wall_posts, posts)
         |> assign(:wall_counts, precompute_wall_counts(posts, user.id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not post comment.")}
    end
  end

  def handle_event("delete_comment", %{"id" => comment_id, "post-id" => post_id}, socket) do
    user_id = socket.assigns.current_user.id
    Timeline.soft_delete_comment(comment_id, user_id)
    comments = reload_comments(socket.assigns.comments, post_id)
    posts = Timeline.list_wall_posts(socket.assigns.profile_user.id, viewer_id: user_id)

    {:noreply,
     socket
     |> assign(:comments, comments)
     |> assign(:wall_posts, posts)
     |> assign(:wall_counts, precompute_wall_counts(posts, user_id))}
  end

  def handle_event("toggle_like", %{"type" => type, "id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    Timeline.toggle_like(user_id, type, id)
    posts = Timeline.list_wall_posts(socket.assigns.profile_user.id, viewer_id: user_id)

    {:noreply,
     assign(socket, wall_posts: posts, wall_counts: precompute_wall_counts(posts, user_id))}
  end

  def handle_event("delete_post", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    Timeline.soft_delete_post(id, user_id)
    posts = Timeline.list_wall_posts(socket.assigns.profile_user.id, viewer_id: user_id)

    {:noreply,
     assign(socket, wall_posts: posts, wall_counts: precompute_wall_counts(posts, user_id))}
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  defp compute_trust(user_id) do
    stats = AIDetection.detection_stats()
    # User is "trusted" if they have approved content and no flags
    user = ParkBench.Accounts.get_user!(user_id)
    not user.ai_flagged and stats.approved > 0
  end

  defp get_cover_thumb(album) do
    case album.cover_photo_id do
      nil ->
        "/images/default-avatar.svg"

      cover_id ->
        case ParkBench.Repo.get(ParkBench.Media.Photo, cover_id) do
          nil -> "/images/default-avatar.svg"
          photo -> photo.thumb_200_url || photo.original_url
        end
    end
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
  def render(assigns) do
    ~H"""
    <div class="profile-page">
      <div class="profile-cover">
        <img
          :if={@profile && @profile.cover_photo_url}
          src={@profile.cover_photo_url}
          alt="Cover photo"
        />
        <div :if={@own_profile} class="cover-photo-overlay">
          <form phx-submit="save_cover_photo" phx-change="validate_upload">
            <label class="cover-photo-edit-btn">
              Edit Cover Photo <.live_file_input upload={@uploads.cover_photo} class="sr-only" />
            </label>
            <button
              :if={@uploads.cover_photo.entries != []}
              type="submit"
              class="btn btn-small btn-blue cover-photo-save"
            >
              Save
            </button>
          </form>
          <div :for={entry <- @uploads.cover_photo.entries} class="cover-photo-preview">
            <.live_img_preview entry={entry} class="cover-preview-img" />
            <button
              type="button"
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              phx-value-upload="cover_photo"
              class="upload-cancel"
            >
              &times;
            </button>
          </div>
        </div>
      </div>
      <div class="profile-header">
        <div :if={@own_profile} class="profile-photo-edit">
          <div class="profile-photo">
            <.profile_thumbnail
              user={@profile_user}
              photo_url={@photo && (@photo.thumb_200_url || @photo.original_url)}
              size={168}
            />
          </div>
          <form
            phx-submit="save_profile_photo"
            phx-change="validate_upload"
            class="profile-photo-upload-form"
          >
            <label class="photo-edit-link">
              Update Photo <.live_file_input upload={@uploads.profile_photo} class="sr-only" />
            </label>
            <button
              :if={@uploads.profile_photo.entries != []}
              type="submit"
              class="btn btn-small btn-blue profile-photo-save"
            >
              Save
            </button>
          </form>
          <div :for={entry <- @uploads.profile_photo.entries} class="profile-photo-preview">
            <.live_img_preview entry={entry} class="profile-preview-img" />
            <button
              type="button"
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              phx-value-upload="profile_photo"
              class="upload-cancel"
            >
              &times;
            </button>
          </div>
        </div>
        <div :if={!@own_profile} class="profile-photo">
          <.profile_thumbnail
            user={@profile_user}
            photo_url={@photo && (@photo.thumb_200_url || @photo.original_url)}
            size={168}
          />
        </div>
        <div class="profile-info">
          <div class="profile-name">
            {@profile_user.display_name}
            <span :if={@trusted} class="trust-badge trust-badge-verified">
              <i class="trust-badge-icon">&#x2713;</i> Verified Human
            </span>
          </div>
          <div :if={@profile && @profile.current_city} class="profile-network">
            Lives in {@profile.current_city}
          </div>
          <div :if={@mutual_count > 0} class="profile-mutual-friends">
            {@mutual_count} mutual friend{if @mutual_count != 1, do: "s"}
          </div>

          <div :if={@current_user.id != @profile_user.id} class="profile-actions">
            <button :if={@relationship == :none} phx-click="send_friend_request" class="btn btn-blue">
              Add Friend
            </button>
            <span :if={@relationship == :friends} class="btn btn-gray">&#10003; Friends</span>
            <span :if={@relationship == :request_sent} class="btn btn-gray">Request Sent</span>
            <button
              :if={@relationship == :friends && !@poked}
              phx-click="send_poke"
              class="btn btn-gray"
            >
              Poke
            </button>
            <span :if={@relationship == :friends && @poked} class="btn btn-gray">Poked!</span>
          </div>
        </div>
      </div>

      <.tab_bar
        tabs={[
          %{id: :wall, label: "Wall", href: ~p"/profile/#{@profile_user.slug}"},
          %{id: :info, label: "Info", href: ~p"/profile/#{@profile_user.slug}/info"},
          %{id: :photos, label: "Photos", href: ~p"/profile/#{@profile_user.slug}/photos"}
        ]}
        active={@live_action}
      />

      <div class="profile-body profile-columns">
        <aside class="col-left">
          <.sidebar_box title={"Friends (#{@friend_count})"}>
            <div class="profile-friends-grid">
              <a
                :for={friend <- @friends}
                href={"/profile/#{friend.slug}"}
                class="profile-friend-item"
              >
                <div class="profile-friend-thumb">
                  <.profile_thumbnail user={friend} size={80} />
                </div>
                <span class="profile-friend-name">{friend.display_name}</span>
              </a>
            </div>
            <a :if={@friend_count > 6} href={~p"/profile/#{@profile_user.slug}/friends"}>
              See All Friends
            </a>
          </.sidebar_box>
        </aside>

        <section class="col-main">
          {# Wall tab}
          <div :if={@live_action == :wall}>
            <div
              :if={Timeline.can_post_on_wall?(@current_user.id, @profile_user.id)}
              class="post-composer"
            >
              <div class="post-composer-header">Write on {@profile_user.display_name}'s Wall</div>
              <div class="post-composer-body">
                <form phx-submit="submit_wall_post" phx-change="validate_upload">
                  <textarea
                    class="form-textarea"
                    name="body"
                    placeholder={"Write something to #{@profile_user.display_name}..."}
                    rows="3"
                    maxlength="5000"
                  >{@new_post_body}</textarea>
                  <div class="post-composer-footer">
                    <label class="photo-attach-btn">
                      Attach Photo <.live_file_input upload={@uploads.wall_photo} class="sr-only" />
                    </label>
                    <button type="submit" class="btn btn-blue">Post</button>
                  </div>
                  <div :for={entry <- @uploads.wall_photo.entries} class="post-composer-photo-preview">
                    <.live_img_preview entry={entry} class="composer-preview-img" />
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      phx-value-upload="wall_photo"
                      class="upload-cancel"
                    >
                      &times;
                    </button>
                  </div>
                </form>
              </div>
            </div>

            <div :if={@wall_posts == []} class="empty-state">
              <div class="empty-state-icon">&#x270E;</div>
              <div class="empty-state-title">No wall posts yet</div>
              <div class="empty-state-text">Be the first to write something on this wall!</div>
            </div>

            <div id="wall-posts" phx-hook="PhotoLightbox">
              <div :for={post <- @wall_posts}>
                <.post_card
                  post={post}
                  current_user_id={@current_user.id}
                  like_count={Map.get(@wall_counts.like_counts, post.id, 0)}
                  comment_count={Map.get(@wall_counts.comment_counts, post.id, 0)}
                  liked={MapSet.member?(@wall_counts.liked_ids, post.id)}
                >
                  <div :if={MapSet.member?(@expanded_comments, post.id)} class="wall-comments">
                    <div :for={comment <- Map.get(@comments, post.id, [])} class="wall-comment">
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
                                @current_user.id == post.author_id ||
                                @current_user.id == post.wall_owner_id
                            }
                            phx-click="delete_comment"
                            phx-value-id={comment.id}
                            phx-value-post-id={post.id}
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
                      id={"profile-comment-form-#{post.id}"}
                    >
                      <form phx-submit="submit_comment">
                        <input type="hidden" name="post-id" value={post.id} />
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
            </div>
          </div>

          {# Info tab}
          <div :if={@live_action == :info} class="profile-info-tab">
            <h2>Information</h2>
            <div :if={@profile} class="info-section">
              <div
                :if={
                  @profile.bio &&
                    Privacy.visible_to?(@privacy.bio_visibility, @current_user.id, @profile_user.id)
                }
                class="info-row"
              >
                <span class="info-label">About:</span>
                <span>{@profile.bio}</span>
              </div>
              <div
                :if={
                  @profile.birthday &&
                    Privacy.visible_to?(
                      @privacy.birthday_visibility,
                      @current_user.id,
                      @profile_user.id
                    )
                }
                class="info-row"
              >
                <span class="info-label">Birthday:</span>
                <span>{@profile.birthday}</span>
              </div>
              <div
                :if={
                  @profile.hometown &&
                    Privacy.visible_to?(
                      @privacy.hometown_visibility,
                      @current_user.id,
                      @profile_user.id
                    )
                }
                class="info-row"
              >
                <span class="info-label">Hometown:</span>
                <span>{@profile.hometown}</span>
              </div>
              <div
                :if={
                  @profile.relationship_status &&
                    Privacy.visible_to?(
                      @privacy.relationship_visibility,
                      @current_user.id,
                      @profile_user.id
                    )
                }
                class="info-row"
              >
                <span class="info-label">Relationship:</span>
                <span>{@profile.relationship_status}</span>
              </div>
              <div
                :if={
                  @profile.interests &&
                    Privacy.visible_to?(
                      @privacy.interests_visibility,
                      @current_user.id,
                      @profile_user.id
                    )
                }
                class="info-row"
              >
                <span class="info-label">Interests:</span>
                <span>{@profile.interests}</span>
              </div>
            </div>
          </div>

          {# Photos tab}
          <div :if={@live_action == :photos} class="profile-photos-tab">
            <div class="photos-tab-header">
              <h2>Photo Albums</h2>
              <a :if={@current_user.id == @profile_user.id} href="/albums/new" class="btn btn-blue">
                + Create Album
              </a>
            </div>

            <div :if={@albums == []} class="empty-state">
              <div class="empty-state-icon">&#x1F4F7;</div>
              <div class="empty-state-title">No photo albums yet</div>
              <div class="empty-state-text">Create an album to start sharing photos!</div>
              <a :if={@current_user.id == @profile_user.id} href="/albums/new" class="btn btn-blue">
                Create Album
              </a>
            </div>

            <div :if={@albums != []} class="album-grid">
              <a :for={album <- @albums} href={"/albums/#{album.id}"} class="album-card">
                <div class="album-cover">
                  <img :if={album.cover_photo_id} src={get_cover_thumb(album)} alt={album.title} />
                  <div :if={is_nil(album.cover_photo_id)} class="album-cover-empty">No Photos</div>
                </div>
                <div class="album-card-info">
                  <span class="album-title">{album.title}</span>
                  <span class="album-count">
                    {album.photo_count} photo{if album.photo_count != 1, do: "s"}
                  </span>
                </div>
              </a>
            </div>
          </div>
        </section>
      </div>
    </div>
    """
  end
end
