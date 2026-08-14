defmodule Bonfire.UI.Console.Web.Routes do
  @moduledoc """
  Self-registering routes, picked up by `Bonfire.UI.Common.RoutesModule.use_modules/0` in the app's
  router — so including or excluding this extension needs no edit to the app repo.
  """

  @behaviour Bonfire.UI.Common.RoutesModule

  defmacro __using__(_) do
    quote do
      # admin_required is enforced here for the HTTP request, and again as a LivePlug in ConsoleLive for the websocket mount, which does not re-run plugs
      scope "/admin", Bonfire.UI.Console do
        pipe_through(:browser)
        pipe_through(:admin_required)

        live("/console", ConsoleLive)
      end
    end
  end
end
