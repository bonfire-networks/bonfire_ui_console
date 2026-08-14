defmodule Bonfire.UI.Console.RevokeTest do
  @moduledoc """
  Revoking from inside a session is the awkward case: the purge kills the shell, the shell is linked to the LiveView that asked for it, so doing it inline takes down the very page meant to show the outcome. The admin gets a crash and a reconnect instead of an answer.

  Expiry is covered separately in `Bonfire.UI.Console.ExpiryTest`, where nothing is watching.
  """

  use Bonfire.UI.Console.ConnCase, async: false

  import Bonfire.UI.Console.TokenHelpers

  @path "/admin/console"

  setup do
    on_exit(fn -> configure(nil) end)

    account = fake_account!()
    admin = fake_admin!(account)

    {:ok, conn: conn(user: admin, account: account)}
  end

  test "revoking returns to the form rather than taking the page down", %{conn: conn} do
    token = in_hours(1)
    configure(token)

    conn
    |> visit(@path)
    |> wait_async()
    |> fill_in("Token", with: token)
    |> click_button("Open console")
    |> wait_async()
    |> assert_has("[data-role=console_terminal]")
    |> click_button("Revoke console access")
    |> wait_async()
    |> assert_has("[data-role=console_token_form]")
    |> refute_has("[data-role=console_terminal]")
  end
end
