defmodule AMQP.Application.Connection do
  @moduledoc false

  use GenServer
  require Logger
  alias AMQP.Connection

  @default_interval 5_000

  @doc """
  Starts a GenServer process linked to the current process.

  It expects options to be a combination of connection args, proc_name and retry_interval.

  ## Examples

  Combines name and retry interval with the connection options.

      iex> opts = [proc_name: :my_conn, retry_interval: 10_000, host: "localhost"]
      iex> :ok = AMQP.Application.Connection.start_link(opts)
      iex> {:ok, conn} = AMQP.Application.Connection.get_connection(:my_conn)

  Passes URL instead of options and use a default proc name when you need only a single connection.

      iex> opts = [url: "amqp://guest:guest@localhost"]
      iex> :ok = AMQP.Application.Connection.start_link(opts)
      iex> {:ok, conn} = AMQP.Application.Connection.get_connection()
      iex> {:ok, conn} = AMQP.Application.Connection.get_connection(:default)
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
    open_arg = Keyword.drop(opts, [:proc_name, :retry_interval])

    init_arg = %{
      retry_interval: retry_interval,
      open_arg: open_arg,
      name: proc_name,
      connection: nil
    }

    {server_name, init_arg}
  end

  @doc """
  Returns a GenServer reference for the connection name
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
  Returns a connection referred by the name.
  """
  @spec get_connection(binary | atom) :: {:ok, Connection.t()} | {:error, any}
  def get_connection(name \\ :default) do
    case GenServer.call(get_server_name(name), :get_connection) do
      nil -> {:error, :not_connected}
      conn -> {:ok, conn}
    end
  end

  @impl true
  def init(state) do
    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call(:get_connection, _, state) do
    {:reply, state[:connection], state}
  end

  @impl true
  def handle_info(:connect, state) do
    case do_open(state[:open_arg]) do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        Process.monitor(conn.pid)
        {:noreply, %{state | connection: conn}}

      {:error, _} ->
        Logger.error("Failed to connect to AMQP server (#{state[:name]}). Retrying later...")

        # Retry later
        Process.send_after(self(), :connect, state[:retry_interval])
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    # Stop GenServer. Will be restarted by Supervisor.
    {:stop, {:connection_gone, reason}, nil}
  end

  defp do_open(options) do
    if url = options[:url] do
      Connection.open(url, Keyword.delete(options, :url))
    else
      Connection.open(options)
    end
  end
end
