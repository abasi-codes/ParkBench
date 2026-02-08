defmodule ParkBench.Accounts.UserProfile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:user_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "user_profiles" do
    field :bio, :string
    field :interests, :string
    field :hometown, :string
    field :current_city, :string
    field :birthday, :date
    field :gender, :string
    field :relationship_status, :string
    field :political_views, :string
    field :religious_views, :string
    field :website, :string
    field :phone, :string
    field :cover_photo_url, :string
    field :bench_streak, :integer, default: 0
    field :last_active_date, :date

    belongs_to :user, ParkBench.Accounts.User, define_field: false

    timestamps(type: :utc_datetime)
  end

  @cast_fields [
    :bio,
    :interests,
    :hometown,
    :current_city,
    :birthday,
    :gender,
    :relationship_status,
    :political_views,
    :religious_views,
    :website,
    :phone,
    :cover_photo_url
  ]

  @valid_genders ["Male", "Female", "Other", "Prefer not to say"]

  @valid_relationship_statuses [
    "Single",
    "In a Relationship",
    "Engaged",
    "Married",
    "It's Complicated",
    "In an Open Relationship",
    "Widowed",
    "Separated",
    "Divorced"
  ]

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, @cast_fields)
    |> validate_length(:bio, max: 2000)
    |> validate_length(:interests, max: 1000)
    |> validate_length(:hometown, max: 255)
    |> validate_length(:current_city, max: 255)
    |> validate_length(:political_views, max: 255)
    |> validate_length(:religious_views, max: 255)
    |> validate_length(:website, max: 500)
    |> validate_length(:phone, max: 20)
    |> validate_inclusion(:gender, @valid_genders)
    |> validate_inclusion(:relationship_status, @valid_relationship_statuses)
    |> validate_birthday()
  end

  def create_changeset(profile, user_id, attrs \\ %{}) do
    profile
    |> changeset(attrs)
    |> put_change(:user_id, user_id)
    |> unique_constraint(:user_id, name: :user_profiles_pkey)
  end

  defp validate_birthday(changeset) do
    case get_change(changeset, :birthday) do
      nil ->
        changeset

      birthday ->
        min_age_date = Date.add(Date.utc_today(), -13 * 365)

        if Date.compare(birthday, min_age_date) == :gt do
          add_error(changeset, :birthday, "you must be at least 13 years old")
        else
          changeset
        end
    end
  end
end
