defmodule AMQP.Application.Connection do
  @moduledoc false
  # This module will stay as a private module at least during 2.0.x.
  # There might be non backward compatible changes on this module on 2.1.x.

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
      iex> {:ok, pid} = AMQP.Application.Connection.start_link(opts)
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
      connection: nil,
      monitor_ref: nil
    }

    {server_name, init_arg}
  end

  @doc """
  Returns a GenServer reference for the connection name.
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
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call(:get_connection, _, state) do
    if state[:connection] && Process.alive?(state[:connection].pid) do
      {:reply, state[:connection], state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_info(:connect, state) do
    case do_open(state[:open_arg]) do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        ref = Process.monitor(conn.pid)
        {:noreply, %{state | connection: conn, monitor_ref: ref}}

      {:error, _} ->
        Logger.error("Failed to open AMQP connection (#{state[:name]}). Retrying later...")

        # Retry later
        Process.send_after(self(), :connect, state[:retry_interval])
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, :process, pid, _reason}, %{connection: %{pid: pid}} = state)
      when is_pid(pid) do
    Logger.info("AMQP connection is gone (#{state[:name]}). Reconnecting...")
    send(self(), :connect)
    {:noreply, %{state | connection: nil, monitor_ref: nil}}
  end

  def handle_info({:EXIT, _from, reason}, state) do
    close(state)
    {:stop, reason, %{state | connection: nil, monitor_ref: nil}}
  end

  @impl true
  def terminate(_reason, state) do
    close(state)
    %{state | connection: nil, monitor_ref: nil}
  end

  defp close(%{connection: %Connection{} = conn, monior_ref: ref}) do
    if Process.alive?(conn.pid) do
      Process.demonitor(ref)
      Connection.close(conn)
    end
  end

  defp close(_), do: :ok

  defp do_open(options) do
    if url = options[:url] do
      Connection.open(url, Keyword.delete(options, :url))
    else
      Connection.open(options)
    end
  end
end
