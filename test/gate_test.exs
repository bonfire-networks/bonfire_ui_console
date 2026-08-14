defmodule Bonfire.UI.Console.GateTest do
  @moduledoc """
  The token in `BONFIRE_CONSOLE_TOKEN` is both the bearer secret and the expiry declaration:
  a UUIDv7 whose embedded 48-bit millisecond timestamp is the moment access ends.
  """

  # not async: the token lives in the OS environment, which is global
  use ExUnit.Case, async: false

  alias Bonfire.UI.Console.Gate
  import Bonfire.UI.Console.TokenHelpers

  setup do
    on_exit(fn -> configure(nil) end)
  end

  describe "with no token configured" do
    setup do
      configure(nil)
      :ok
    end

    test "is not armed" do
      refute Gate.armed?()
      assert Gate.expires_at() == nil
    end

    test "authorises nothing, including nil and empty" do
      refute Gate.authorised?(nil)
      refute Gate.authorised?("")
      refute Gate.authorised?(in_hours(24))
    end
  end

  describe "with a future-dated token" do
    setup do
      token = in_hours(24)
      configure(token)
      {:ok, token: token}
    end

    test "is armed, and reports the expiry embedded in the token", %{token: token} do
      assert Gate.armed?()
      assert %DateTime{} = expires = Gate.expires_at()

      {:ok, ms} = Needle.UID.timestamp(token)
      assert DateTime.to_unix(expires, :millisecond) == ms
      assert DateTime.compare(expires, DateTime.utc_now()) == :gt
    end

    test "authorises exactly that token", %{token: token} do
      assert Gate.authorised?(token)
    end

    test "refuses any other token", %{token: token} do
      refute Gate.authorised?(in_hours(24))
      refute Gate.authorised?(String.replace(token, ~r/^./, "f"))
      refute Gate.authorised?(nil)
      refute Gate.authorised?("")
    end
  end

  describe "with an expired token" do
    setup do
      token = hours_ago(1)
      configure(token)
      {:ok, token: token}
    end

    test "is not armed even though a token is configured" do
      refute Gate.armed?()
    end

    test "refuses the configured token itself", %{token: token} do
      refute Gate.authorised?(token)
    end
  end

  describe "with a ULID token" do
    setup do
      ulid = Needle.ULID.generate(System.system_time(:millisecond) + 3_600_000)
      configure(ulid)
      {:ok, token: ulid}
    end

    test "accepts it — either UID encoding carries the same 48-bit ms field", %{token: ulid} do
      assert Gate.armed?()
      assert Gate.authorised?(ulid)
      assert %DateTime{} = Gate.expires_at()
    end

    test "still refuses a different token", %{token: ulid} do
      refute Gate.authorised?(in_hours(24))
      refute Gate.authorised?(near_miss(ulid))
    end
  end

  describe "with a token that carries no timestamp" do
    test "refuses a UUIDv4" do
      v4 = "7232b37d-fc13-44c0-8e1b-9a5a07e24921"
      configure(v4)

      refute Gate.armed?()
      refute Gate.authorised?(v4)
    end

    test "refuses malformed input" do
      for bad <- ["", "not-a-uuid", "0188a516-bc8c-7c5a-9b68"] do
        configure(bad)

        refute Gate.armed?()
        refute Gate.authorised?(bad)
      end
    end
  end
end
