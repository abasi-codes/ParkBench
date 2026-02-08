defmodule Sunporch.Timeline.WallPost do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wall_posts" do
    field :body, :string
    field :ai_detection_status, :string, default: "pending"
    field :ai_detection_score, :float
    field :content_hash, :string
    field :photo_url, :string
    field :deleted_at, :utc_datetime

    belongs_to :author, Sunporch.Accounts.User
    belongs_to :wall_owner, Sunporch.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(wall_post, attrs) do
    wall_post
    |> cast(attrs, [:author_id, :wall_owner_id, :body, :photo_url, :ai_detection_status, :ai_detection_score])
    |> validate_required([:author_id, :wall_owner_id])
    |> validate_body_or_photo()
    |> validate_length(:body, max: 5000)
    |> generate_content_hash()
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:wall_owner_id)
  end

  defp validate_body_or_photo(changeset) do
    body = get_field(changeset, :body)
    photo_url = get_field(changeset, :photo_url)

    if (is_nil(body) || body == "") && (is_nil(photo_url) || photo_url == "") do
      add_error(changeset, :body, "or a photo is required")
    else
      changeset
    end
  end

  defp generate_content_hash(changeset) do
    case get_change(changeset, :body) do
      nil -> changeset
      body ->
        hash = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
        put_change(changeset, :content_hash, hash)
    end
  end
end
