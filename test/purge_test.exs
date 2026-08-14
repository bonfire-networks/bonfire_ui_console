defmodule Bonfire.UI.Console.PurgeTest do
  @moduledoc """
  What the console hands to `Bonfire.Common.Extend.purge_modules/1`, which is the whole of its
  disarming: everything that could open or sustain a session goes, and nothing that has to keep
  answering afterwards does.

  The purge mechanism itself is covered in `Bonfire.Common.ExtendPurgeTest`.
  """

  use ExUnit.Case, async: true

  alias Bonfire.UI.Console.Gate
  alias Bonfire.UI.Console.PurgeWorker

  describe "purge_targets/0" do
    test "includes the terminal module" do
      assert Bonfire.UI.Console.Terminal in Gate.purge_targets()
    end

    test "includes the gate, so no code is left that can read or match the token" do
      assert Gate in Gate.purge_targets()
    end

    test "includes the terminal dependencies, which are what a session actually runs on" do
      assert ExTTY in Gate.purge_targets()
      assert Underthehood in Gate.purge_targets()
    end

    test "never includes the routed LiveView, which must survive to keep refusals uniform" do
      # a purged routed module would still be matched by the compiled router, then raise undef ->
      # a 500, which both breaks the identical-response property and announces the console exists
      refute Bonfire.UI.Console.ConsoleLive in Gate.purge_targets()
    end

    test "never includes the worker carrying out the purge, which would abort it part-way" do
      refute PurgeWorker in Gate.purge_targets()
    end
  end
end
