defmodule Bonfire.UI.Console.PurgeWorker do
  @moduledoc """
  Everything about *when* the console gets disarmed.

  Two triggers, distinguished by arity:

    * `run/0` — `Bonfire.Common.StartupTask`, once per boot. Unarmed (no token, malformed, or already expired) it purges straight away, so an instance that merely *ships* the extension carries nothing usable in memory. Armed, it schedules the purge for the instant embedded in the token.

    * `perform/1` — `Oban.Worker`, at that instant. Purges, which is what makes an open session die at expiry rather than merely being refused on the next mount.

  It also triggers the purge from here, rather than from something that gets purged: `Bonfire.UI.Console.Gate` is one of the targets, so anything running from there would be killing its own caller part-way through the list.

  Nothing is persisted between boots: the token is re-read and the schedule re-derived every time, so a restart cannot extend a window, and a changed token takes effect immediately. Oban is used for visibility and cancellability in the dashboard at `/admin/system/oban`, not for durability.
  """

  use Oban.Worker,
    queue: :scheduled,
    max_attempts: 3,
    # `:infinity` because the point is "a purge is already pending", regardless of how long ago it was inserted, the default 60s window would let every boot stack another
    unique: [period: :infinity, states: [:available, :scheduled, :executing, :retryable]]

  @behaviour Bonfire.Common.StartupTask

  alias Bonfire.Common.Extend
  alias Bonfire.UI.Console.Gate
  import Untangle

  @doc "At boot: schedule the purge if armed, otherwise purge now."
  @impl Bonfire.Common.StartupTask
  def run do
    case Gate.expires_at() do
      %DateTime{} = expires_at ->
        info("console is armed until #{expires_at}, scheduling its purge for then")

        %{}
        |> new(scheduled_at: expires_at)
        |> Oban.insert()

      _ ->
        # Gate already logged the specific reason
        purge()
    end
  end

  @doc """
  At expiry: purge.

  Idempotent — purging modules that are already gone is a no-op, so a retry or a duplicate job costs nothing.
  """
  @impl Oban.Worker
  def perform(_job), do: purge()

  @doc """
  Disarms this instance by purging everything in `Bonfire.UI.Console.Gate.purge_targets/0`.

  With `Gate` itself among the targets, a second run has nothing left to ask and nothing left to purge.
  """
  def purge do
    if Code.ensure_loaded?(Gate) do
      info("disarming the console")
      Extend.purge_modules(Gate.purge_targets())
    else
      info("console was already disarmed")
      :ok
    end
  end

  @doc """
  Purges once `pid` has gone, so revoking from inside a session doesn't take down the page meant to show the outcome.

  The shell is linked to the LiveView that started it, so purging inline kills the caller mid-click and the admin gets a crash and a reconnect instead of an answer. Waiting for that LiveView to navigate away is cosmetic; the timeout is not, since a session that never closes must not hold the grant open.

  Has to live here rather than in `Bonfire.UI.Console.Terminal`, even though that is what calls it: the spawned process runs whichever module defines this closure, and `Terminal` is purged second, before the terminal dependencies. A waiter defined there would be killed part-way through its own purge, leaving the shell alive.
  """
  def purge_when_gone(pid, timeout \\ 5_000) do
    spawn(fn ->
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        timeout -> warn("console session stayed up for #{timeout}ms, disarming anyway")
      end

      purge()
    end)
  end
end
