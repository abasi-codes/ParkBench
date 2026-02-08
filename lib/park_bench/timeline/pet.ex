defmodule ParkBench.Timeline.Pet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_species ["dog", "cat", "bird", "rabbit", "fish", "hamster", "other"]
  @valid_moods ["playful", "sleepy", "curious", "energetic", "relaxed", "hungry", "cuddly"]

  schema "pets" do
    field :name, :string
    field :species, :string
    field :breed, :string
    field :age_years, :integer
    field :mood, :string
    field :emoji, :string, default: "\u{1F43E}"
    field :photo_url, :string
    field :deleted_at, :utc_datetime

    belongs_to :user, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(pet, attrs) do
    pet
    |> cast(attrs, [:user_id, :name, :species, :breed, :age_years, :mood, :emoji, :photo_url])
    |> validate_required([:user_id, :name, :species])
    |> validate_inclusion(:species, @valid_species)
    |> validate_inclusion(:mood, @valid_moods ++ [nil])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_length(:breed, max: 100)
    |> validate_number(:age_years, greater_than_or_equal_to: 0, less_than_or_equal_to: 30)
    |> foreign_key_constraint(:user_id)
  end
end
