defmodule Sunporch.Privacy.PrivacySetting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "privacy_settings" do
    field :profile_visibility, :string, default: "everyone"
    field :bio_visibility, :string, default: "friends"
    field :interests_visibility, :string, default: "friends"
    field :education_visibility, :string, default: "friends"
    field :work_visibility, :string, default: "friends"
    field :birthday_visibility, :string, default: "friends"
    field :hometown_visibility, :string, default: "friends"
    field :current_city_visibility, :string, default: "friends"
    field :phone_visibility, :string, default: "only_me"
    field :email_visibility, :string, default: "only_me"
    field :relationship_visibility, :string, default: "friends"
    field :wall_posting, :string, default: "friends"
    field :friend_list_visibility, :string, default: "friends"
    field :search_visible, :boolean, default: true

    belongs_to :user, Sunporch.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @visibility_fields [
    :profile_visibility,
    :bio_visibility,
    :interests_visibility,
    :education_visibility,
    :work_visibility,
    :birthday_visibility,
    :hometown_visibility,
    :current_city_visibility,
    :phone_visibility,
    :email_visibility,
    :relationship_visibility,
    :wall_posting,
    :friend_list_visibility,
    :search_visible
  ]

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:user_id | @visibility_fields])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end
end
