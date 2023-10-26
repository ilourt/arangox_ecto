defmodule ArangoXEcto.Migrator do
  @moduledoc """
  The migrator is responsible for running and rolling back migrations.
  """

  require Logger
  alias Mix.ArangoXEcto, as: Helpers

  @doc """
  Runs Migration/Rollback functions for specified db
  """
  def migrate(db_name, opts) do
    case opts do
      {[], []} ->
        up(db_name)

      {[dir: "up"], _} ->
        up(db_name)

      {_, ["up"]} ->
        up(db_name)

      {[dir: "down"], _} ->
        down(db_name)

      {_, ["down"]} ->
        down(db_name)

      {_, ["rollback"]} ->
        down(db_name)

      {_, _} ->
        {:error, "Unknown arguments provided, #{inspect(Enum.join(opts, " "))}"}
    end
  end

  defp up(db_name) do
    migrated = Helpers.migrated_versions(db_name)

    pending_migrations()
    |> Enum.filter(fn file_path ->
      t_stamp = timestamp(file_path)
      not Enum.member?(migrated, t_stamp)
    end)
    |> maybe_up_migrations(db_name)
  end

  defp maybe_up_migrations([], _db_name), do: Mix.shell().info("No migrations to action :)")

  defp maybe_up_migrations(migrations, db_name) do
    Enum.each(migrations, fn file_path ->
      case migration_module(file_path).up() do
        nil ->
          Logger.error("Up function has no actions")

        :ok ->
          file_path
          |> timestamp()
          |> Helpers.update_versions(db_name)

          Logger.info("Successfully Migrated #{file_path}")

        {:error, reason} ->
          Logger.info("Unable to Migrate #{file_path}")
          Logger.error("Status: #{inspect(reason)}")
      end
    end)
  end

  @spec down(binary()) :: :ok
  def down(db_name) do
    [last_migrated_version | _] = versions(db_name)

    module =
      last_migrated_version
      |> migration_path()
      |> migration_module()

    case module.down() do
      nil ->
        Logger.error("Down function has no actions")

      :ok ->
        Helpers.remove_version(last_migrated_version, db_name)

        Logger.info("Successfully Rolled Back #{last_migrated_version}")

      _ ->
        Logger.info("Unable to Rollback #{last_migrated_version}")
    end
  end

  defp migration_module(path) do
    {{:module, module, _, _}, _} =
      Helpers.get_default_repo!()
      |> Helpers.path_to_priv_repo()
      |> Path.join("migrations")
      |> Path.join(path)
      |> Code.eval_file()

    module
  end

  defp migration_path(version) when not is_binary(version) do
    version
    |> to_string()
    |> migration_path()
  end

  defp migration_path(version) do
    Helpers.get_default_repo!()
    |> Helpers.path_to_priv_repo()
    |> Path.join("migrations")
    |> File.ls!()
    |> Enum.find(&String.starts_with?(&1, version))
  end

  defp pending_migrations do
    Helpers.get_default_repo!()
    |> Helpers.path_to_priv_repo()
    |> Path.join("migrations")
    |> File.ls!()
    |> Enum.filter(&(!String.starts_with?(&1, ".")))
    |> Enum.sort(&(timestamp(&1) <= timestamp(&2)))
  end

  defp timestamp(path) do
    path
    |> String.split("_")
    |> hd()
    |> String.to_integer()
  end

  defp versions(db_name) do
    Helpers.migrated_versions(db_name)
    |> Enum.sort(&(&1 >= &2))
  end
end
