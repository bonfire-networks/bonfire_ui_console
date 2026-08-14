defmodule Bonfire.UI.Console.AuditLabelTest do
  use Bonfire.UI.Console.ConnCase, async: false

  import ExUnit.CaptureLog
  import Bonfire.UI.Console.TokenHelpers

  alias Bonfire.UI.Console.Terminal

  @path "/admin/console"

  describe "audit_label/2" do
    test "is username and address when both are known" do
      user = %{character: %{username: "alice"}}

      assert Terminal.audit_label(user, "203.0.113.7") == "alice from 203.0.113.7"
    end

    test "omits the address rather than logging an empty 'from'" do
      assert Terminal.audit_label(%{character: %{username: "alice"}}, nil) == "alice"
    end

    test "still says something when the user can't be identified" do
      assert Terminal.audit_label(nil, "203.0.113.7") == "unknown user from 203.0.113.7"
      assert Terminal.audit_label(nil, nil) == "unknown user"
    end
  end

  describe "in a real session" do
    setup do
      on_exit(fn -> configure(nil) end)

      account = fake_account!()
      admin = fake_admin!(account)

      {:ok, conn: conn(user: admin, account: account), admin: admin}
    end

    test "opening logs the acting admin", %{conn: conn, admin: admin} do
      token = in_hours(24)
      configure(token)

      username = admin.character.username

      log =
        capture_log(fn ->
          conn
          |> visit(@path)
          |> wait_async()
          |> fill_in("Token", with: token)
          |> click_button("Open console")
          |> wait_async()
          |> assert_has("[data-role=console_terminal]")
        end)

      assert log =~ "console opened by #{username}"
    end
  end
end
