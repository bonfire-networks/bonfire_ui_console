defmodule Bonfire.UI.Console.AnonymousConsoleTest do
  @moduledoc """
  The console page is for admins only, but its events are also reachable by a plain request to the `/LiveHandler` route, which carries no session at all. A visitor without a session must not be able to open a console, even with the right token.

  Opening a console is recorded in the log as `console opened by ...`, so a refusal is a log without that line. A test where an admin opens one with the same token shows the line does appear.
  """

  use Bonfire.UI.Console.ConnCase, async: false

  import Bonfire.UI.Console.TokenHelpers
  import ExUnit.CaptureLog

  setup do
    on_exit(fn -> configure(nil) end)

    token = in_hours(24)
    configure(token)

    {:ok, token: token}
  end

  test "an admin opening a console with the right token is logged (control)", %{token: token} do
    account = fake_account!()
    admin = fake_admin!(account)

    log =
      capture_log(fn ->
        conn(user: admin, account: account)
        |> visit("/admin/console")
        |> wait_async()
        |> fill_in("Token", with: token)
        |> click_button("Open console")
        |> wait_async()
      end)

    assert log =~ "console opened by"
  end

  test "a visitor without a session cannot open a console, even with the right token", %{
    token: token
  } do
    log =
      capture_log(fn ->
        # the request may fail while rendering its answer, what matters is whether a console was opened first
        try do
          get(build_conn(), "/LiveHandler/Bonfire.UI.Console.ConsoleLive/open?token=#{token}")
        rescue
          _ -> :ok
        end
      end)

    refute log =~ "console opened by"
  end
end
