defmodule ParkBench.Accounts.EducationEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "education_entries" do
    field :school_name, :string
    field :degree, :string
    field :field_of_study, :string
    field :start_year, :integer
    field :end_year, :integer
    field :description, :string

    belongs_to :user, ParkBench.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :user_id,
      :school_name,
      :degree,
      :field_of_study,
      :start_year,
      :end_year,
      :description
    ])
    |> validate_required([:user_id, :school_name])
    |> validate_length(:school_name, min: 1, max: 255)
    |> validate_length(:degree, max: 255)
    |> validate_length(:field_of_study, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_number(:start_year, greater_than: 1900, less_than_or_equal_to: 2030)
    |> validate_number(:end_year, greater_than: 1900, less_than_or_equal_to: 2030)
    |> validate_year_range()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_year_range(changeset) do
    start_year = get_field(changeset, :start_year)
    end_year = get_field(changeset, :end_year)

    cond do
      is_nil(start_year) or is_nil(end_year) ->
        changeset

      end_year < start_year ->
        add_error(changeset, :end_year, "must be after or equal to start year")

      true ->
        changeset
    end
  end
end
