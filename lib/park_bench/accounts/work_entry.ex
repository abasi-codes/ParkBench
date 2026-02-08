defmodule ParkBench.Accounts.WorkEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "work_entries" do
    field :company_name, :string
    field :position, :string
    field :city, :string
    field :start_date, :date
    field :end_date, :date
    field :description, :string
    field :is_current, :boolean, default: false

    belongs_to :user, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :user_id,
      :company_name,
      :position,
      :city,
      :start_date,
      :end_date,
      :description,
      :is_current
    ])
    |> validate_required([:user_id, :company_name, :position])
    |> validate_length(:company_name, min: 1, max: 255)
    |> validate_length(:position, min: 1, max: 255)
    |> validate_length(:city, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_date_range()
    |> validate_current_has_no_end_date()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_date_range(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    cond do
      is_nil(start_date) or is_nil(end_date) ->
        changeset

      Date.compare(end_date, start_date) == :lt ->
        add_error(changeset, :end_date, "must be after or equal to start date")

      true ->
        changeset
    end
  end

  defp validate_current_has_no_end_date(changeset) do
    is_current = get_field(changeset, :is_current)
    end_date = get_field(changeset, :end_date)

    if is_current && not is_nil(end_date) do
      add_error(changeset, :end_date, "must be empty if this is your current position")
    else
      changeset
    end
  end
end
