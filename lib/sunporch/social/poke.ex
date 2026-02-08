defmodule Sunporch.Social.Poke do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pokes" do
    belongs_to :poker, Sunporch.Accounts.User
    belongs_to :pokee, Sunporch.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(poke, attrs) do
    poke
    |> cast(attrs, [:poker_id, :pokee_id])
    |> validate_required([:poker_id, :pokee_id])
    |> validate_not_self_poke()
    |> unique_constraint([:poker_id, :pokee_id], name: :pokes_poker_id_pokee_id_index)
    |> foreign_key_constraint(:poker_id)
    |> foreign_key_constraint(:pokee_id)
  end

  defp validate_not_self_poke(changeset) do
    poker_id = get_field(changeset, :poker_id)
    pokee_id = get_field(changeset, :pokee_id)

    if poker_id == pokee_id do
      add_error(changeset, :pokee_id, "cannot poke yourself")
    else
      changeset
    end
  end
end
