defmodule Bonfire.UI.Console.ConsoleLiveTest do
  @moduledoc """
  The console page must be a poor oracle: neither whether the instance is armed, nor whether a
  submitted token was close, may be observable. Every refusal looks the same.
  """

  use Bonfire.UI.Console.ConnCase, async: false

  import Bonfire.UI.Console.TokenHelpers

  @path "/admin/console"

  # the single message every refusal gives, whatever actually went wrong
  @refusal "Unable to open a console"

  setup do
    on_exit(fn -> configure(nil) end)

    account = fake_account!()
    admin = fake_admin!(account)

    {:ok, conn: conn(user: admin, account: account), account: account, admin: admin}
  end

  describe "as an admin" do
    test "the form renders whether or not the instance is armed", %{conn: conn} do
      configure(nil)

      conn
      |> visit(@path)
      |> wait_async()
      |> assert_has("[data-role=console_token_form]")

      configure(in_hours(24))

      conn
      |> visit(@path)
      |> wait_async()
      |> assert_has("[data-role=console_token_form]")
    end

    test "a valid token opens the terminal", %{conn: conn} do
      token = in_hours(24)
      configure(token)

      conn
      |> visit(@path)
      |> wait_async()
      |> fill_in("Token", with: token)
      |> click_button("Open console")
      |> wait_async()
      # the bundle URL is rendered here rather than on the hook element, which belongs to the
      # underthehood dep, so the shim looks it up on the nearest ancestor carrying it
      |> assert_has("[data-role=console_terminal][data-terminal-bundle]")
    end

    # asserting each case gives the SAME message, not merely that each is "an error" — a test that
    # only checked for some error would pass while the page still leaked which failure occurred
    for {label, configured, submitted} <- [
          {"unarmed", nil, :fresh},
          {"expired token", {:ago, 1}, :configured},
          {"wrong token", {:in, 24}, :fresh},
          {"near miss", {:in, 24}, :near_miss},
          {"malformed", {:in, 24}, "not-a-uuid"},
          {"empty", {:in, 24}, ""}
        ] do
      test "refusal is identical: #{label}", %{conn: conn} do
        configured =
          case unquote(Macro.escape(configured)) do
            nil -> nil
            {:in, n} -> in_hours(n)
            {:ago, n} -> hours_ago(n)
          end

        configure(configured)

        submitted =
          case unquote(Macro.escape(submitted)) do
            :fresh -> in_hours(24)
            :configured -> configured
            :near_miss -> near_miss(configured)
            literal -> literal
          end

        conn
        |> visit(@path)
        |> wait_async()
        |> fill_in("Token", with: submitted)
        |> click_button("Open console")
        |> wait_async()
        |> refute_has("[data-role=console_terminal]")
        |> assert_has("[data-role=console_refusal]", text: @refusal)
      end
    end
  end

  test "a non-admin cannot reach the page even with a valid token" do
    configure(in_hours(24))

    account = fake_account!()
    user = fake_user!(account)

    conn(user: user, account: account)
    |> visit(@path)
    |> wait_async()
    |> refute_has("[data-role=console_token_form]")
  end
end
