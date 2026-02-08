defmodule Sunporch.Accounts.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sessions" do
    field :token_hash, :string
    field :ip_address, :string
    field :user_agent, :string
    field :last_active_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :user, Sunporch.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:user_id, :token_hash, :ip_address, :user_agent, :expires_at, :last_active_at])
    |> validate_required([:user_id, :token_hash, :expires_at])
    |> validate_length(:ip_address, max: 45)
    |> validate_length(:user_agent, max: 500)
    |> foreign_key_constraint(:user_id)
  end

  def touch_changeset(session) do
    change(session, last_active_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end
end
