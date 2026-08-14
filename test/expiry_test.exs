defmodule Bonfire.UI.Console.ExpiryTest do
  @moduledoc """
  Expiry has to *end* a session in progress, not merely refuse the next one. An admin who opened a
  console and walked away must not still have a live shell an hour later.

  The mechanism is `:code.purge/1`, which terminates processes running the purged code — so this
  asserts on process death rather than on any predicate.
  """

  use Bonfire.UI.Console.ConnCase, async: false

  import Bonfire.UI.Console.TokenHelpers

  alias Bonfire.UI.Console.PurgeWorker

  @path "/admin/console"

  setup do
    on_exit(fn -> configure(nil) end)

    account = fake_account!()
    admin = fake_admin!(account)

    {:ok, conn: conn(user: admin, account: account)}
  end

  test "purging at expiry kills the running shell", %{conn: conn} do
    token = in_hours(1)
    configure(token)

    before = shell_pids()

    conn
    |> visit(@path)
    |> wait_async()
    |> fill_in("Token", with: token)
    |> click_button("Open console")
    |> wait_async()
    |> assert_has("[data-role=console_terminal]")

    # precondition: a shell really is running. Without this the test would pass vacuously against a
    # session that never started one.
    shells = shell_pids() -- before
    assert shells != [], "expected an ExTTY shell process for the open session"
    assert Enum.all?(shells, &Process.alive?/1)

    refs = Enum.map(shells, &Process.monitor/1)

    # what the Oban job does when the token's timestamp arrives
    PurgeWorker.perform(%Oban.Job{args: %{}})

    for ref <- refs do
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}, 2_000
    end

    refute Enum.any?(shells, &Process.alive?/1)
  end

  # ExTTY is a GenServer started by the terminal component; find them by initial call rather than by
  # reaching into the LiveView, since the linkage is an implementation detail of the dep
  defp shell_pids do
    for pid <- Process.list(),
        # nil for a process that died mid-scan, which this filters out
        {:dictionary, dict} <- [Process.info(pid, :dictionary)],
        match?({ExTTY, _, _}, dict[:"$initial_call"]),
        do: pid
  end
end
