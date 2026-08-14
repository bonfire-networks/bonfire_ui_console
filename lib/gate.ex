defmodule Bonfire.UI.Console.Gate do
  @moduledoc """
  Decides whether this instance is armed for console access, and until when.

  The whole configuration is a single env var, `BONFIRE_CONSOLE_TOKEN`, holding a **time-ordered UID whose embedded 48-bit millisecond timestamp is the expiry**. It is simultaneously the expiry declaration and the bearer secret the grantee presents. Either UID encoding works, since both carry that field and ample randomness: a UUIDv7 (mint one at <https://uuidv7.org/> for the date access should end) or a ULID. UUID versions with no timestamp, such as v4, are refused.

  Enabling a token requires editing the environment and restarting, which needs deploy access.

  This module is itself purged when the grant lapses (see `Bonfire.UI.Console.PurgeWorker`), so a disarmed instance has no code left that knows what the token is for, let alone how to match one.

  Every refusal logs its specific reason here, which is what callers rely on: they deliberately expose a single indistinguishable response to the client (see `Bonfire.UI.Console.ConsoleLive`), so the server log is the only place the reason exists.
  """

  import Untangle
  use Bonfire.Common.Localise
  alias Bonfire.Common.DatesTimes

  @env_var "BONFIRE_CONSOLE_TOKEN"

  @doc "Whether a valid, unexpired token is configured."
  def armed?, do: not is_nil(grant())

  @doc "When the configured grant expires, or `nil` if not armed."
  def expires_at do
    case grant() do
      %{expires_at: expires_at} -> expires_at
      _ -> nil
    end
  end

  @doc """
  Whether `presented` is the configured token and the window is still open.

  Compared in constant time, so a wrong token leaks nothing through timing.
  """
  def authorised?(presented) when is_binary(presented) and presented != "" do
    case grant() do
      %{token: token} -> Plug.Crypto.secure_compare(presented, token)
      _ -> false
    end
  end

  def authorised?(_), do: false

  @doc """
  The modules deleted and purged when the grant lapses, or was never valid.

  Includes this module: once the grant lapses nothing should be left that can read the token or
  match one against it, and the environment — not this module — is where the secret actually lives,
  so nothing is lost by removing the only code that knows to look there.

  Deliberately excludes `Bonfire.UI.Console.ConsoleLive`, since routes are compiled into the
  router, so purging never removes one: a purged routed module would still be matched, then called,
  raising `undef` → a 500. That breaks the identical-response property *and* announces that a
  console exists here. It survives so it can return the same refusal itself.

  Also excludes `Bonfire.UI.Console.PurgeWorker`, which carries out the purge and so cannot be one
  of its victims.
  """
  def purge_targets do
    [__MODULE__, Bonfire.UI.Console.Terminal] ++ app_modules(:underthehood) ++ app_modules(:extty)
  end

  defp app_modules(app), do: Application.spec(app, :modules) || []

  defp grant do
    case System.get_env(@env_var) do
      token when is_binary(token) and token != "" -> validate(token)
      _ -> nil
    end
  end

  # accepts either UIDv7 or ULID, both of which carry a timestamp
  defp validate(token) do
    case DatesTimes.date_from_pointer(token) do
      %DateTime{} = expires_at ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
          %{token: token, expires_at: expires_at}
        else
          warn("console token expired at #{expires_at}, refusing")
          nil
        end

      _ ->
        # never log the token itself
        warn("#{@env_var} is not a time-ordered UID, so the console stays disarmed")
        nil
    end
  end
end
