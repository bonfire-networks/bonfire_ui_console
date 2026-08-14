defmodule Bonfire.UI.Console.RuntimeConfig do
  use Bonfire.Common.Localise

  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  @doc """
  Sets runtime configuration for the extension (typically by reading ENV variables).
  """
  def config do
    import Config

    config :bonfire_common, Bonfire.Common.StartupTasks,
      run: [console_purge: Bonfire.UI.Console.PurgeWorker]
  end
end
