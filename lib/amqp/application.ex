defmodule AMQP.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    load_config()
    children = load_connections() ++ load_channels()

    opts = [
      strategy: :one_for_one,
      name: AMQP.Application,
      max_restarts: length(children) * 2,
      max_seconds: 1
    ]

    Supervisor.start_link(children, opts)
  end

  defp load_config do
    unless Application.get_env(:amqp, :enable_progress_report, false) do
      disable_progress_report()
    end
  end

  defp load_connections do
    conn = Application.get_env(:amqp, :connection)
    conns = Application.get_env(:amqp, :connections, [])
    conns = if conn, do: conns ++ [default: conn], else: conns

    Enum.map(conns, fn {name, opts} ->
      arg = opts ++ [proc_name: name]
      id = AMQP.Application.Connection.get_server_name(name)
      Supervisor.child_spec({AMQP.Application.Connection, arg}, id: id)
    end)
  end

  defp load_channels do
    chan = Application.get_env(:amqp, :channel)
    chans = Application.get_env(:amqp, :channels, [])
    chans = if chan, do: chans ++ [default: chan], else: chans

    Enum.map(chans, fn {name, opts} ->
      arg = opts ++ [proc_name: name]
      id = AMQP.Application.Channel.get_server_name(name)
      Supervisor.child_spec({AMQP.Application.Channel, arg}, id: id)
    end)
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
  rescue
    e ->
      Logger.warn("Failed to disable progress report by Erlang library: detail: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Enables the progress report logging from Erlang library.
  """
  @spec enable_progress_report :: :ok | {:error, any}
  def enable_progress_report do
    case :logger.remove_primary_filter(:amqp_ignore_rabbitmq_progress_reports) do
      :ok -> :ok
      # filter already removed
      {:error, {:not_found, _}} -> :ok
      error -> error
    end
  end
end
