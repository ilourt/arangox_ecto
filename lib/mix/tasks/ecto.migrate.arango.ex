defmodule Mix.Tasks.Ecto.Migrate.Arango do
  @moduledoc """
  Runs Migration/Rollback functions from migration modules
  """

  use Mix.Task

  alias Mix.ArangoXEcto, as: Helpers

  @aliases [
    d: :dir
  ]

  @switches [
    dir: :string
  ]

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    db_name = Helpers.get_database_name!()

    case Helpers.migrated_versions(db_name) do
      [nil] ->
        Mix.raise("ArangoXEcto is not set up, run `mix ecto.setup.arango` first.")

      _ ->
        opts = OptionParser.parse!(args, aliases: @aliases, strict: @switches)
        migrate(db_name, opts)
    end
  end

  defp migrate(db_name, opts) do
    case ArangoXEcto.Migrator.migrate(db_name, opts) do
      {:error, error} -> Mix.raise(error)
      _ -> nil
    end
  end
end
