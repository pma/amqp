defmodule AMQP.Channel.ReceiverManager do
  @moduledoc false
  # Manages receivers.
  #
  # AMQP relays messages from a channel to a client and convert
  # [Record](https://hexdocs.pm/elixir/Record.html) to the data structure which
  # is familiar with Elixir developer (Tuple, Map).
  # We call the processes in between a channel and a client Receiver and
  # this module manages them.
  #
  # This module ensures to have a single Receiver per a channel and a client.
  # With that way, the sequence of the messages from channel would be always
  # preserved.

  use GenServer
  alias AMQP.Channel.Receiver

  @enforce_keys [:pid, :channel, :client]
  @type t :: %__MODULE__{
    pid: pid(),
    channel: pid(),
    client: pid(),
  }
  defstruct [:pid, :channel, :client]

  @doc false
  @spec start_link(map) :: GenServer.on_start()
  def start_link(opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @impl true
  def init(state = %{}) do
    {:ok, state}
  end

  @doc """
  Returns a receiver pid for the channel and client.
  """
  @spec get_receiver(pid(), pid()) :: t() | nil
  def get_receiver(channel, client) do
    GenServer.call(__MODULE__, {:get, channel, client})
  end

  @doc """
  Unregisters a receiver from GenServer.
  """
  @spec unregister_receiver(pid(), pid()) :: :ok
  def unregister_receiver(channel, client) do
    GenServer.call(__MODULE__, {:unregister, channel, client})
  end

  @doc """
  Registers a receiver pid for the channel and client.
  """
  @spec register_handler(pid(), pid(), atom(), keyword()) :: t() | nil
  def register_handler(channel, client, handler, opts \\ []) do
    GenServer.call(__MODULE__, {:register_handler, channel, client, handler, opts})
  end

  @impl true
  def handle_call({:get, channel, client}, _from, receivers) do
    key = get_key(channel, client)
    {:reply, Map.get(receivers, key), receivers}
  end

  def handle_call({:unregister, channel, client}, _from, receivers) do
    key = get_key(channel, client)
    {:reply, :ok, Map.delete(receivers, key)}
  end

  def handle_call({:register_handler, channel, client, handler, opts}, _from, receivers) do
    receiver =
      receivers
      |> get_or_spawn_receiver(channel, client)
      |> add_handler(handler, opts)

    key = get_key(channel, client)
    {:reply, receiver, Map.put(receivers, key, receiver)}
  end

  defp get_receiver(receivers, channel, client) do
    key = get_key(channel, client)
    if (receiver = receivers[key]) && Process.alive?(receiver.pid) do
      receiver
    else
      nil
    end
  end

  defp get_or_spawn_receiver(receivers, channel, client) do
    if receiver = get_receiver(receivers, channel, client) do
      receiver
    else
      spawn_receiver(channel, client)
    end
  end

  defp add_handler(receiver, handler, opts) do
    send(receiver.pid, {:add_handler, handler, opts})
    receiver
  end

  defp spawn_receiver(channel, client) do
    receiver_pid = spawn fn ->
      Process.flag(:trap_exit, true)
      Process.monitor(channel)
      Process.monitor(self())
      Receiver.handle_message(channel, client, %{})
    end

    %__MODULE__{
      pid: receiver_pid,
      channel: channel,
      client: client
    }
  end

  defp get_key(channel, client) do
    "#{inspect channel}-#{inspect client}"
  end
end
