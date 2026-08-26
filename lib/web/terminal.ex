defmodule Bonfire.UI.Console.Terminal do
  @moduledoc """
  The purgeable half of the console: authorisation, the session UI, and the audit binding.

  As much as possible lives here, because everything here *stops existing* when the grant lapses. `Bonfire.UI.Console.ConsoleLive` can't be purged — routes are compiled into the router, so purging a routed module leaves the route matching a deleted module and raising `undef`, a 500 that both breaks the uniform-refusal property and announces a console exists here. So it survives holding only the form, and delegates everything else to this module.

  Notably `authorise/2`: with this module gone there is no authorisation path at all, so refusal is by construction rather than by a branch someone could later invert.

  Purging also kills the shell: `ExTTY.start_link/1` is called from the LiveView process, so the shell is linked to it, and `:code.purge/1` terminates processes running the purged code.
  """

  use Bonfire.UI.Common.Web, :live_component

  require Logger

  alias Bonfire.UI.Console.Gate
  alias Bonfire.UI.Console.PurgeWorker

  @doc "Whether `token` opens a session, and the label to attribute it to."
  def authorise(token, current_user, client_ip \\ nil) do
    if Gate.authorised?(token) do
      label = audit_label(current_user, client_ip)

      # `warning`, not `info`: opening a root shell is the audit trail's whole point, so it has to survive the log level being turned down. Prod defaults to `warning` and CI runs at `notice`, both above `info`, so this was being recorded nowhere that matters. Matches the level the per-command transcript already uses
      Logger.warning("console opened by #{label}")
      {:ok, label}
    else
      :error
    end
  end

  @doc """
  Identifies the acting admin in the audit transcript.
  """
  def audit_label(user, client_ip \\ nil) do
    [e(user, :character, :username, nil) || "unknown user", client_ip]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" from ")
  end

  def handle_event("close", _params, socket) do
    Logger.warning("console access revoked by #{e(assigns(socket), :session, nil)}")

    # navigate away first, so the purge has no live session left to kill mid-render
    PurgeWorker.purge_when_gone(self())

    {:noreply, push_navigate(socket, to: "/admin/console")}
  end
end
