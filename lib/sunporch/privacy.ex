defmodule Sunporch.Privacy do
  @moduledoc "Privacy settings and visibility controls"

  alias Sunporch.Repo
  alias Sunporch.Privacy.PrivacySetting

  @visibility_options ["everyone", "friends", "only_me"]

  def get_privacy_settings(user_id) do
    case Repo.get_by(PrivacySetting, user_id: user_id) do
      nil ->
        %PrivacySetting{}
        |> PrivacySetting.changeset(%{user_id: user_id})
        |> Repo.insert!()
      settings -> settings
    end
  end

  def update_privacy_settings(user_id, attrs) do
    settings = get_privacy_settings(user_id)
    settings
    |> PrivacySetting.changeset(attrs)
    |> Repo.update()
  end

  def visible_to?(field_visibility, viewer_id, owner_id) do
    cond do
      viewer_id == owner_id -> true
      field_visibility == "everyone" -> true
      field_visibility == "only_me" -> false
      field_visibility == "friends" -> Sunporch.Social.friends?(owner_id, viewer_id)
      true -> false
    end
  end

  def can_view_profile?(viewer_id, owner_id) do
    settings = get_privacy_settings(owner_id)
    visible_to?(settings.profile_visibility, viewer_id, owner_id)
  end

  def can_post_on_wall?(poster_id, owner_id) do
    settings = get_privacy_settings(owner_id)
    visible_to?(settings.wall_posting, poster_id, owner_id)
  end

  def visibility_options, do: @visibility_options
end
