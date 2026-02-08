defmodule ParkBench.Repo.Migrations.AddFullTextSearchIndexes do
  use Ecto.Migration

  def up do
    # Add tsvector column for full-text search
    alter table(:users) do
      add :search_vector, :tsvector
    end

    # Create GIN index on search_vector
    execute "CREATE INDEX users_search_vector_gin ON users USING gin(search_vector)"

    # Create trigger function to auto-update search_vector from display_name and email
    execute """
    CREATE FUNCTION users_search_vector_update() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.display_name, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.email::text, '')), 'B');
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """

    # Create trigger that fires on insert or update
    execute """
    CREATE TRIGGER users_search_vector_trigger
      BEFORE INSERT OR UPDATE OF display_name, email
      ON users
      FOR EACH ROW
      EXECUTE FUNCTION users_search_vector_update()
    """

    # Backfill existing rows
    execute """
    UPDATE users SET search_vector =
      setweight(to_tsvector('english', coalesce(display_name, '')), 'A') ||
      setweight(to_tsvector('english', coalesce(email::text, '')), 'B')
    """

    # Create GIN trigram index on display_name for ILIKE prefix searches
    execute "CREATE INDEX users_display_name_trgm ON users USING gin(display_name gin_trgm_ops)"
  end

  def down do
    execute "DROP INDEX IF EXISTS users_display_name_trgm"
    execute "DROP TRIGGER IF EXISTS users_search_vector_trigger ON users"
    execute "DROP FUNCTION IF EXISTS users_search_vector_update()"
    execute "DROP INDEX IF EXISTS users_search_vector_gin"

    alter table(:users) do
      remove :search_vector
    end
  end
end
