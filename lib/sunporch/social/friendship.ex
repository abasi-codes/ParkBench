defmodule Sunporch.Social.Friendship do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "friendships" do
    belongs_to :user, Sunporch.Accounts.User
    belongs_to :friend, Sunporch.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:user_id, :friend_id])
    |> validate_required([:user_id, :friend_id])
    |> validate_ordered_ids()
    |> validate_not_self_friendship()
    |> unique_constraint([:user_id, :friend_id], name: :friendships_user_id_friend_id_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:friend_id)
  end

  defp validate_ordered_ids(changeset) do
    user_id = get_field(changeset, :user_id)
    friend_id = get_field(changeset, :friend_id)

    cond do
      is_nil(user_id) or is_nil(friend_id) ->
        changeset

      user_id >= friend_id ->
        add_error(changeset, :user_id, "must be less than friend_id (store the lower ID as user_id)")

      true ->
        changeset
    end
  end

  defp validate_not_self_friendship(changeset) do
    user_id = get_field(changeset, :user_id)
    friend_id = get_field(changeset, :friend_id)

    if user_id == friend_id do
      add_error(changeset, :friend_id, "cannot be friends with yourself")
    else
      changeset
    end
  end
end
