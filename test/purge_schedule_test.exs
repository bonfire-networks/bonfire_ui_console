defmodule Bonfire.UI.Console.PurgeScheduleTest do
  @moduledoc """
  At boot the console either disarms itself immediately, or schedules its own disarming for the
  instant embedded in the token.
  """

  use Bonfire.UI.Console.DataCase, async: false

  import Bonfire.UI.Console.TokenHelpers
  alias Bonfire.UI.Console.PurgeWorker

  @repo Bonfire.Common.Repo
  @worker Bonfire.UI.Console.PurgeWorker

  setup do
    on_exit(fn -> configure(nil) end)
  end

  describe "with a future-dated token" do
    test "schedules the purge for the instant embedded in the token" do
      token = in_hours(24)
      configure(token)

      PurgeWorker.run()

      Oban.Testing.assert_enqueued(@repo, worker: @worker)

      {:ok, expires_ms} = Needle.UID.timestamp(token)
      job = enqueued_purge_job()

      assert DateTime.to_unix(job.scheduled_at, :millisecond) == expires_ms
    end

    test "a second boot with the same token does not stack a duplicate" do
      configure(in_hours(24))

      PurgeWorker.run()
      PurgeWorker.run()

      assert length(all_purge_jobs()) == 1
    end

    test "does not purge yet — the window is still open" do
      configure(in_hours(24))

      # precondition: the terminal is there to be purged, so this can't pass vacuously
      assert Code.ensure_loaded?(Bonfire.UI.Console.Terminal)

      PurgeWorker.run()

      # function_exported?/3 never loads, unlike Code.ensure_loaded?/1 which would reload it here
      assert function_exported?(Bonfire.UI.Console.Terminal, :authorise, 3)
    end
  end

  describe "with no usable token" do
    test "purges immediately and schedules nothing" do
      configure(nil)

      PurgeWorker.run()

      assert all_purge_jobs() == []
      Oban.Testing.refute_enqueued(@repo, worker: @worker)
    end

    test "an already-expired token is treated the same as none" do
      configure(hours_ago(1))

      PurgeWorker.run()

      assert all_purge_jobs() == []
    end
  end

  defp all_purge_jobs, do: Oban.Testing.all_enqueued(@repo, worker: @worker)

  defp enqueued_purge_job, do: all_purge_jobs() |> List.first()
end
