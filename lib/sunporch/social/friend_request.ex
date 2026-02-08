defmodule Sunporch.Social.FriendRequest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ["pending", "accepted", "rejected", "cancelled"]

  schema "friend_requests" do
    field :status, :string, default: "pending"

    belongs_to :sender, Sunporch.Accounts.User
    belongs_to :receiver, Sunporch.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [:sender_id, :receiver_id, :status])
    |> validate_required([:sender_id, :receiver_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_not_self_request()
    |> unique_constraint([:sender_id, :receiver_id], name: :friend_requests_sender_id_receiver_id_index)
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:receiver_id)
  end

  def status_changeset(request, attrs) do
    request
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
  end

  def accept_changeset(request) do
    change(request, status: "accepted")
  end

  def reject_changeset(request) do
    change(request, status: "rejected")
  end

  def cancel_changeset(request) do
    change(request, status: "cancelled")
  end

  defp validate_not_self_request(changeset) do
    sender_id = get_field(changeset, :sender_id)
    receiver_id = get_field(changeset, :receiver_id)

    if sender_id == receiver_id do
      add_error(changeset, :receiver_id, "cannot send a friend request to yourself")
    else
      changeset
    end
  end
end
