defmodule AMQP.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = []

    load_config()

    opts = [strategy: :one_for_one, name: AMQP.Application]
    Supervisor.start_link(children, opts)
  end

  defp load_config do
    unless Application.get_env(:amqp, :enable_progress_report, false) do
      disable_progress_report()
    end
  end

  @doc """
  Disables the progress report logging from Erlang library.

  The log outputs are very verbose and can contain credentials.
  This AMQP library recommends to disable unless you want the information.
  """
  @spec disable_progress_report :: :ok | {:error, any}
  def disable_progress_report do
    :logger.add_primary_filter(
      :amqp_ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    :ok
  rescue
    e ->
      Logger.warn("Failed to disable progress report by Erlang library: detail: #{inspect(e)}")
      {:error, e}
  end
end
