defmodule AMQP.Application.Channel do
  @moduledoc false

  # This module will stay as a private module at least during 2.0.x.
  # There might be non backward compatible changes on this module on 2.1.x.

  use GenServer
  require Logger
  alias AMQP.Channel

  @default_interval 5_000

  @doc """
  Starts a GenServer process linked to the current process.

  ## Examples

  Combines name and retry interval with the connection options.

      iex> opts = [proc_name: :my_chan, retry_interval: 10_000, connection: :my_conn]
      iex> :ok = AMQP.Application.Channel.start_link(opts)
      iex> {:ok, chan} = AMQP.Application.Channel.get_channel(:my_chan)

  If you omit the proc_name, it uses :default.

      iex> :ok = AMQP.Application.Channel.start_link([])
      iex> {:ok, chan} = AMQP.Application.Channel.get_channel()
      iex> {:ok, chan} = AMQP.Application.Channel.get_channel(:default)
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
      monitor_ref: nil,
      channel: nil
    }

    {server_name, init_arg}
  end

  @doc """
  Returns a GenServer reference for the channel name.
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
  @spec get_channel(binary | atom) :: {:ok, Channel.t()} | {:error, any}
  def get_channel(name \\ :default) do
    case GenServer.call(get_server_name(name), :get_channel) do
      nil -> {:error, :channel_not_ready}
      channel -> {:ok, channel}
    end
  end

  @impl true
  def init(state) do
    send(self(), :open)
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call(:get_channel, _, state) do
    if state[:channel] && Process.alive?(state[:channel].pid) do
      {:reply, state[:channel], state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_info(:open, state) do
    case AMQP.Application.Connection.get_connection(state[:connection]) do
      {:ok, conn} ->
        case Channel.open(conn) do
          {:ok, chan} ->
            ref = Process.monitor(chan.pid)
            {:noreply, %{state | channel: chan, monitor_ref: ref}}

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

  def handle_info({:DOWN, _, :process, pid, _reason}, %{channel: %{pid: pid}} = state)
      when is_pid(pid) do
    Logger.info("AMQP channel is gone (#{state[:name]}). Reopening...")
    send(self(), :open)
    {:noreply, %{state | channel: nil, monitor_ref: nil}}
  end

  def handle_info({:EXIT, _from, reason}, state) do
    close(state)
    {:stop, reason, %{state | channel: nil, monitor_ref: nil}}
  end

  @impl true
  def terminate(_reason, state) do
    close(state)
    %{state | channel: nil, monitor_ref: nil}
  end

  defp close(%{channel: %Channel{} = channel, monior_ref: ref}) do
    if Process.alive?(channel.pid) do
      Process.demonitor(ref)
      Channel.close(channel)
    end
  end

  defp close(_), do: :ok
end
