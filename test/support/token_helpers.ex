defmodule Bonfire.UI.Console.TokenHelpers do
  @moduledoc """
  Builders for console tokens in tests.

  The console accepts any time-ordered UID whose embedded 48-bit millisecond field is the expiry,
  so tests need to mint one at an arbitrary instant — past or future. There is deliberately no
  generator in the shipped code (operators use <https://uuidv7.org/>), hence these live here.
  """

  @env_var "BONFIRE_CONSOLE_TOKEN"

  @doc "Sets or clears `BONFIRE_CONSOLE_TOKEN`."
  def configure(nil), do: System.delete_env(@env_var)
  def configure(token), do: System.put_env(@env_var, token)

  @doc "A well-formed UUIDv7 carrying the given ms timestamp, built the way RFC 9562 specifies."
  def uuid_v7_at(ms) do
    <<rand_a::12, _::6, rand_b::62>> = :crypto.strong_rand_bytes(10)
    {:ok, uuid} = Ecto.UUID.load(<<ms::48, 7::4, rand_a::12, 2::2, rand_b::62>>)
    uuid
  end

  @doc "A UUIDv7 expiring `n` hours from now."
  def in_hours(n), do: uuid_v7_at(now_ms() + n * 3_600_000)

  @doc "A UUIDv7 that expired `n` hours ago."
  def hours_ago(n), do: uuid_v7_at(now_ms() - n * 3_600_000)

  @doc """
  A token of the same length differing in exactly one character.

  Picks the replacement off the actual last character rather than assuming one: current-era ULIDs
  all begin `0`, so mutating the FIRST character to `0` silently yields the identical string and
  the assertion passes for no reason.
  """
  def near_miss(token) do
    replacement = if String.last(token) == "Z", do: "Y", else: "Z"
    String.slice(token, 0..-2//1) <> replacement
  end

  defp now_ms, do: System.system_time(:millisecond)
end
