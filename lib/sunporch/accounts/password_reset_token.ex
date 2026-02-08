defmodule Sunporch.Accounts.PasswordResetToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @token_validity_hours 1
  @token_byte_size 32

  schema "password_reset_tokens" do
    field :token, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    belongs_to :user, Sunporch.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(token_record, attrs) do
    token_record
    |> cast(attrs, [:user_id, :token, :expires_at, :used_at])
    |> validate_required([:user_id, :token, :expires_at])
    |> unique_constraint(:token)
    |> foreign_key_constraint(:user_id)
  end

  def generate_token(user_id) do
    token = :crypto.strong_rand_bytes(@token_byte_size) |> Base.url_encode64(padding: false)

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@token_validity_hours * 3600, :second)
      |> DateTime.truncate(:second)

    %__MODULE__{}
    |> changeset(%{user_id: user_id, token: token, expires_at: expires_at})
  end

  def mark_used_changeset(token_record) do
    change(token_record, used_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  def used?(%__MODULE__{used_at: used_at}), do: not is_nil(used_at)
end
