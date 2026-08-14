defmodule Bonfire.UI.Console.ConsoleLive do
  @moduledoc """
  The routed page: a token form, and a delegation.

  It cannot be purged, because routes are compiled into the router — so it holds only what must still render once disarmed, and nothing else. Authorisation, the terminal, the audit binding and the session UI all live in `Bonfire.UI.Console.Terminal`, which is purged, leaving no code path here that could say yes.

  Every refusal renders one identical message: anything else would tell a prober whether this instance is armed and whether a guess was close. Refusing is therefore this module's job too, `Bonfire.UI.Console.Gate` is purged along with everything else, and something has to still answer once it is.
  """

  use Bonfire.UI.Common.Web, :live_view

  on_mount({LivePlugs,
            [Bonfire.UI.Me.LivePlugs.LoadCurrentUser, Bonfire.UI.Me.LivePlugs.AdminRequired]})

  alias Bonfire.UI.Console.Terminal

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: l("Console"),
       session: nil,
       refusal: nil,
       # a terminal wants the width, and there is nothing contextual to put beside it
       without_secondary_widgets: true
     )}
  end

  def handle_event("open", %{"token" => token}, socket) do
    # user_ip is already assigned for every LiveView by Bonfire.UI.Common.LivePlugHelpers
    case available?() &&
           Terminal.authorise(token, current_user(socket), e(assigns(socket), :user_ip, nil)) do
      {:ok, session} -> {:noreply, assign(socket, session: session, refusal: nil)}
      _ -> {:noreply, assign(socket, session: nil, refusal: refuse())}
    end
  end

  @doc "Whether the terminal machinery is still loaded, i.e. whether this instance is armed."
  def available?, do: Code.ensure_loaded?(Terminal)

  @doc """
  Logs that a console was refused and returns the one message the client is ever shown.

  The client learns nothing beyond this string, not whether the instance is armed, nor whether the token was close. The specific reason is logged where it is known: whether the terminal is still there is known here, why a token was rejected only in `Bonfire.UI.Console.Gate`.
  """
  def refuse do
    warn("console refused (available?=#{available?()})")
    l("Unable to open a console")
  end
end
