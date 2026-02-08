defmodule Sunporch.Timeline.FeedItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_item_types [
    "wall_post",
    "status_update",
    "new_friendship",
    "friend_added",
    "profile_photo_updated",
    "profile_updated"
  ]

  schema "feed_items" do
    field :item_type, :string
    field :content_id, :binary_id

    belongs_to :user, Sunporch.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(feed_item, attrs) do
    feed_item
    |> cast(attrs, [:user_id, :item_type, :content_id])
    |> validate_required([:user_id, :item_type, :content_id])
    |> validate_inclusion(:item_type, @valid_item_types)
    |> foreign_key_constraint(:user_id)
  end
end
