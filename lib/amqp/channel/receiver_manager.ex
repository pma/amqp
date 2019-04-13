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
    count: integer()
  }
  defstruct [:pid, :channel, :client, {:count, 0}]

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

  When check_in option is true, it counts up the handlers and responds unregister properly.
  """
  @spec get_receiver(pid(), pid(), keyword()) :: pid()
  def get_receiver(channel, client, opts \\ []) do
    GenServer.call(__MODULE__, {:get, channel, client, opts})
  end

  @impl true
  def handle_call({:get, channel, client, opts}, _from, receivers) do
    receiver =
      receivers
      |> get_or_spawn_receiver(channel, client)
      |> check_in(opts[:check_in])

    key = get_key(channel, client)
    {:reply, receiver, Map.put(receivers, key, receiver)}
  end

  defp get_or_spawn_receiver(receivers, channel, client) do
    key = get_key(channel, client)
    if (receiver = receivers[key]) && Process.alive?(receiver.pid) do
      receiver
    else
      spawn_receiver(channel, client)
    end
  end

  defp spawn_receiver(channel, client) do
    receiver_pid = spawn fn ->
      Process.flag(:trap_exit, true)
      Process.monitor(channel)
      Process.monitor(client)
      Process.monitor(self())
      Receiver.handle_message(channel, client)
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

  defp check_in(receiver, true),
    do: Map.put(receiver, :count, receiver.count + 1)
  defp check_in(receiver, _), do: receiver
end
