defmodule AMQP.Application do
  @moduledoc """
  Provides access to configured connections and channels.
  """

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

  @doc """
  Provides an easy way to access an AMQP connection.

  The connection will be monitored by AMQP's GenServer and it will
  automatically try to reconnect when the connection is gone.

  ## Usage

  When you want to have a single connection in your app:

      config :amqp, connection: [
          url: "amqp://guest:guest@localhost:15672"
        ]

  You can also use any options available on `AMQP.Connection.open/2`:

      config :amqp, connection: [
          host: "localhost",
          port: 15672
          username: "guest",
          password: "guest"
        ]

  Then the connection will be open at the start of the application and you can
  access via this function.

      iex> {:ok, conn} = AMQP.Application.get_connection()

  By default, it tries to connect to your local RabbitMQ. You can simply pass
  the empty keyword list too:

      config :amqp, connection: [] # == [url: "amqp://0.0.0.0"]

  You can set up multiple connections wth `:connections` key:

      config :amqp, connections: [
          business_report: [
            url: "amqp://host1"
          ],
          analytics: [
            url: "amqp://host2"
          ]
        ]

  Then you can access each connection with its name.

      iex> {:ok, conn1} = AMQP.Application.get_connection(:business_report)
      iex> {:ok, conn2} = AMQP.Application.get_connection(:analytics)

  The default name is :default so These two configurations are equivalent:

      config :amqp, connection: []
      config :amqp, connections: [default: []]

  ## Configuration options

    * `:retry_interval` - The retry interval in milliseconds when the connection
      is failed to open. (default `5000`)

    * `:url` - AMQP URI for the connection

  See also `AMQP.Connection.open/2` for all available options.
  """
  @spec get_connection(binary | atom) :: {:ok, AMQP.Connection.t()} | {:error, any}
  def get_connection(name \\ :default) do
    AMQP.Application.Connection.get_connection(name)
  end

  @doc """
  Provides an easy way to access an AMQP channel.

  AMQP.Application provides a wrapper on top of `AMQP.Channel` with .

  The channel will be monitored by AMQP's GenServer and it will automatically
  try to reopen when the channel is gone.

  ## Usage

  When you want to have a single channel in your app:

      config :amqp,
        connection: [url: "amqp://guest:guest@localhost:15672"],
        channel: []

  Then the channel will be open at the start of the application and you can
  access it via this function.

      iex> {:ok, chan} = AMQP.Application.get_channel()

  You can also set up multiple channels with `:channels` key:

      config :amqp,
        connections: [
          business_report: [url: "amqp://host1"],
          analytics: [url: "amqp://host2"]
        ],
        channels: [
          bisiness_report: [connection: :business_report],
          analytics: [connection: :analytics]
        ]

  Then you can access each channel with its name.

      iex> {:ok, conn1} = AMQP.Application.get_channel(:business_report)
      iex> {:ok, conn2} = AMQP.Application.get_channel(:analytics)

  You can also have multiple channels for a single connection.

      config :amqp,
        connection: [],
        channels: [
          consumer: [],
          producer: []
        ]

  ## Configuration options

    * `:connection` - The connection name configured with `connection` or
      `connections` (default `:default`)

    * `:retry_interval` - The retry interval in milliseconds when the channel is
      failed to open (default `5000`)

  ## Caveat

  Although AMQP will reopen the named channel automatically when it is closed
  for some reasons, your application still needs to monitor the channel for a
  consumer process.

  Be aware the channel reopened doesn't automatically recover the subscription
  of your consumer

  Here is a sample GenServer module that monitors the channel and re-subscribe
  the channel.

      defmodule AppConsumer do
        use GenServer
        @channel :default
        @queue "myqueue"

        ....

        def handle_info(:subscribe, state) do
          case subscribe() do
            {:ok, chan} ->
              {:noreply, Map.put(state, :channel, chan)}
            _ ->
              {:noreply, state}
          end
        end

        def handle_info({:DOWN, _, :process, pid, reason}, %{channel: %{pid: pid}} = state) do
          send(self(), :subscribe)
          {:noreply, Map.put(state, :channel, nil)}
        end

        defp subscribe() do
          case AMQP.Application.get_channel(@channel) do
            {:ok, chan} ->
              Process.monitor(chan.pid)
              AMQP.Basic.consume(@channel, @queue)

            _error ->
              Process.send_after(self(), :subscribe, 1000)
              {:error, :retrying}
          end
        end
      end

  """
  @spec get_channel(binary | atom) :: {:ok, AMQP.Channel.t()} | {:error, any}
  def get_channel(name \\ :default) do
    AMQP.Application.Channel.get_channel(name)
  end
end
