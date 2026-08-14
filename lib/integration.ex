defmodule Bonfire.UI.Console do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()

  use Bonfire.Common.Config
  use Bonfire.Common.Localise
  import Untangle
  import Bonfire.Common.Modularity.DeclareHelpers
  alias Bonfire.Common.Utils

  declare_extension(
    l("Console"),
    icon: "bi:terminal",
    description: l("A time-limited web IEx console for admins")
  )

  def repo, do: Config.repo()
end
