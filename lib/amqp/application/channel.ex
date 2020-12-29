defmodule AMQP.Application.Channel do
  @moduledoc false

  use GenServer
  require Logger
  alias AMQP.{Channel, Connection}

  @default_interval 5_000

  @doc """
  Starts a GenServer process linked to the current process.

  ## Examples

  Combines name and retry interval with the connection options.

      iex> opts = [proc_name: :my_chan, retry_interval: 10_000, connection: :my_conn]
      iex> :ok = AMQP.Application.Channel.start_link(opts)
      iex> {:ok, chan} = AMQP.Application.Connection.get_connection(:my_chan)

  If you omit the proc_name, it uses :default.

      iex> :ok = AMQP.Application.Channel.start_link([])
      iex> {:ok, chan} = AMQP.Application.Connection.get_channel()
      iex> {:ok, chan} = AMQP.Application.Connection.get_channel(:default)
  """
  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts) do
    {name, init_arg} = link_opts_to_init_arg(opts)

    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  defp link_opts_to_init_arg(opts) do
    proc_name = Keyword.get(opts, :proc_name, :default)
    server_name = get_server_name(proc_name)
    retry_interval = Keyword.get(opts, :retry_interval, @default_interval)
    connection = Keyword.get(opts, :connection, proc_name)

    init_arg = %{
      retry_interval: retry_interval,
      connection: connection,
      name: proc_name,
      channel: nil
    }

    {server_name, init_arg}
  end

  @doc """
  Returns a GenServer reference for the channel name
  """
  @spec get_server_name(binary | atom) :: binary
  def get_server_name(name) do
    :"#{__MODULE__}::#{name}"
  end

  @doc false
  def get_state(name \\ :default) do
    GenServer.call(get_server_name(name), :get_state)
  end

  @doc """
  Returns pid for the server referred by the name.

  It is a wrapper of `GenServer.whereis/1`.
  """
  @spec whereis(binary() | atom()) :: pid() | {atom(), node()} | nil
  def whereis(name) do
    name
    |> get_server_name()
    |> GenServer.whereis()
  end

  @doc """
  Returns a channel referred by the name.
  """
  @spec get_channel(binary | atom) :: {:ok, Connection.t()} | {:error, any}
  def get_channel(name \\ :default) do
    case GenServer.call(get_server_name(name), :get_channel) do
      nil -> {:error, :channel_not_ready}
      channel -> {:ok, channel}
    end
  end

  @impl true
  def init(state) do
    send(self(), :open)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call(:get_channel, _, state) do
    {:reply, state[:channel], state}
  end

  @impl true
  def handle_info(:open, state) do
    case AMQP.Application.Connection.get_connection(state[:connection]) do
      {:ok, conn} ->
        case Channel.open(conn) do
          {:ok, chan} ->
            Process.monitor(chan.pid)
            {:noreply, %{state | channel: chan}}

          {:error, error} ->
            Logger.error("Failed to open an AMQP channel(#{state[:name]}) - #{inspect(error)}")
            Process.send_after(self(), :open, state[:retry_interval])
            {:noreply, state}
        end

      _error ->
        Logger.error(
          "Failed to open an AMQP channel(#{state[:name]}). Connection (#{state[:connection]}) is not ready."
        )

        Process.send_after(self(), :open, state[:retry_interval])
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    # Stop GenServer. Will be restarted by Supervisor.
    {:stop, {:channel_gone, reason}, nil}
  end
end
