defmodule Bonfire.UI.Console.AnonymousConsoleCloseTest do
  @moduledoc """
  Revoking the console purges its code from the running instance, so only an admin with an open session may do it. A visitor without a session who sends `close` through the plain `/LiveHandler` route must not revoke anything.

  Revoking is recorded in the log as `console access revoked by ...`, and schedules a purge of the console modules. Because that purge is global, this is the only test in its file.
  """

  use Bonfire.UI.Console.ConnCase, async: false

  import Bonfire.UI.Console.TokenHelpers
  import ExUnit.CaptureLog

  setup do
    on_exit(fn -> configure(nil) end)
    configure(in_hours(24))
    :ok
  end

  test "a visitor without a session cannot revoke an armed console" do
    log =
      capture_log(fn ->
        # the request may fail while rendering its answer, what matters is whether the revoke went ahead first
        try do
          get(build_conn(), "/LiveHandler/Bonfire.UI.Console.Terminal/close")
        rescue
          _ -> :ok
        end
      end)

    refute log =~ "console access revoked by"
  end
end
