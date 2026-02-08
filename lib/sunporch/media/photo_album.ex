defmodule Sunporch.Media.PhotoAlbum do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "photo_albums" do
    field :title, :string
    field :description, :string
    field :photo_count, :integer, default: 0
    field :cover_photo_id, :binary_id

    belongs_to :user, Sunporch.Accounts.User

    has_many :photos, Sunporch.Media.Photo, foreign_key: :album_id

    timestamps(type: :utc_datetime)
  end

  def changeset(album, attrs) do
    album
    |> cast(attrs, [:title, :description, :user_id, :cover_photo_id])
    |> validate_required([:title, :user_id])
    |> validate_length(:title, min: 1, max: 100)
    |> validate_length(:description, max: 1000)
    |> foreign_key_constraint(:user_id)
  end
end
