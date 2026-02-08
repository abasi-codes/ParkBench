defmodule ParkBench.Companions do
  @moduledoc "Pet and kid profile management"

  import Ecto.Query
  alias ParkBench.Repo
  alias ParkBench.Timeline.{Pet, PetEmbed, Kid, KidEmbed}

  # === Pets ===

  def list_pets(user_id) do
    Pet
    |> where([p], p.user_id == ^user_id and is_nil(p.deleted_at))
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  def get_pet!(id), do: Repo.get!(Pet, id)

  def create_pet(user_id, attrs) do
    %Pet{}
    |> Pet.changeset(Map.put(attrs, :user_id, user_id))
    |> Repo.insert()
  end

  def update_pet(%Pet{} = pet, attrs) do
    pet
    |> Pet.changeset(attrs)
    |> Repo.update()
  end

  def delete_pet(pet_id, user_id) do
    pet = get_pet!(pet_id)

    if pet.user_id != user_id do
      {:error, :unauthorized}
    else
      pet
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update()
    end
  end

  def create_pet_embed(wall_post_id, pet_id, attrs \\ %{}) do
    %PetEmbed{}
    |> PetEmbed.changeset(Map.merge(attrs, %{wall_post_id: wall_post_id, pet_id: pet_id}))
    |> Repo.insert()
  end

  # === Kids ===

  def list_kids(user_id) do
    Kid
    |> where([k], k.user_id == ^user_id and is_nil(k.deleted_at))
    |> order_by([k], asc: k.name)
    |> Repo.all()
  end

  def get_kid!(id), do: Repo.get!(Kid, id)

  def create_kid(user_id, attrs) do
    %Kid{}
    |> Kid.changeset(Map.put(attrs, :user_id, user_id))
    |> Repo.insert()
  end

  def update_kid(%Kid{} = kid, attrs) do
    kid
    |> Kid.changeset(attrs)
    |> Repo.update()
  end

  def delete_kid(kid_id, user_id) do
    kid = get_kid!(kid_id)

    if kid.user_id != user_id do
      {:error, :unauthorized}
    else
      kid
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update()
    end
  end

  def create_kid_embed(wall_post_id, kid_id, attrs \\ %{}) do
    %KidEmbed{}
    |> KidEmbed.changeset(Map.merge(attrs, %{wall_post_id: wall_post_id, kid_id: kid_id}))
    |> Repo.insert()
  end
end
