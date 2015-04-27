defmodule AMQP.Queue do
  @moduledoc """
  Functions to operate on Queues.
  """

  import AMQP.Core

  alias AMQP.Channel
  alias AMQP.Basic

  @doc """
  Declares a queue. The optional `queue` parameter is used to set the name.
  If set to an empty string (default), the server will assign a name.

  Besides the queue name, the following options can be used:

  # Options

    * `:durable` - If set, keeps the Queue between restarts of the broker
    * `:auto-delete` - If set, deletes the Queue once all subscribers disconnect
    * `:exclusive` - If set, only one subscriber can consume from the Queue
    * `:passive` - If set, raises an error unless the queue already exists

  """
  def declare(%Channel{pid: pid}, queue \\ "", options \\ []) do
    queue_declare =
      queue_declare(queue:       queue,
                    passive:     Keyword.get(options, :passive,     false),
                    durable:     Keyword.get(options, :durable,     false),
                    exclusive:   Keyword.get(options, :exclusive,   false),
                    auto_delete: Keyword.get(options, :auto_delete, false),
                    nowait:      Keyword.get(options, :no_wait,     false),
                    arguments:   Keyword.get(options, :arguments,   []))
    queue_declare_ok(queue:          queue,
                     message_count:  message_count,
                     consumer_count: consumer_count) = :amqp_channel.call pid, queue_declare
    {:ok, %{queue: queue, message_count: message_count, consumer_count: consumer_count}}
  end

  @doc """
  Binds a Queue to an Exchange
  """
  def bind(%Channel{pid: pid}, queue, exchange, options \\ []) do
    queue_bind =
      queue_bind(queue:       queue,
                 exchange:    exchange,
                 routing_key: Keyword.get(options, :routing_key, ""),
                 nowait:      Keyword.get(options, :no_wait,     false),
                 arguments:   Keyword.get(options, :arguments,   []))
    queue_bind_ok() = :amqp_channel.call pid, queue_bind
    :ok
  end

  @doc """
  Unbinds a Queue from an Exchange
  """
  def unbind(%Channel{pid: pid}, queue, exchange, options \\ []) do
    queue_unbind =
      queue_unbind(queue:       queue,
                   exchange:    exchange,
                   routing_key: Keyword.get(options, :routing_key, ""),
                   arguments:   Keyword.get(options, :arguments,   []))
    queue_unbind_ok() = :amqp_channel.call pid, queue_unbind
    :ok
  end

  @doc """
  Deletes a Queue by name
  """
  def delete(%Channel{pid: pid}, queue, options \\ []) do
    queue_delete =
      queue_delete(queue:     queue,
                   if_unused: Keyword.get(options, :if_unused, false),
                   if_empty:  Keyword.get(options, :if_empty,  false),
                   nowait:    Keyword.get(options, :no_wait,   false))
    queue_delete_ok(message_count: message_count) = :amqp_channel.call pid, queue_delete
    {:ok, %{message_count: message_count}}
  end

  @doc """
  Discards all messages in the Queue
  """
  def purge(%Channel{pid: pid}, queue) do
    queue_purge_ok(message_count: message_count) = :amqp_channel.call pid, queue_purge(queue: queue)
    {:ok, %{message_count: message_count}}
  end

  @doc """
  Returns the message count and consumer count for the given queue.
  Uses Queue.declare with the `passive` option set.
  """
  def status(%Channel{} = chan, queue) do
    declare(chan, queue, passive: true)
  end

  @doc """
  Returns the number of messages that are ready for delivery (e.g. not pending acknowledgements)
  in the queue
  """
  def message_count(%Channel{} = channel, queue) do
    {:ok, %{message_count: message_count}} = status(channel, queue)
    message_count
  end

  @doc """
  Returns a number of active consumers on the queue
  """
  def consumer_count(%Channel{} = channel, queue) do
    {:ok, %{consumer_count: consumer_count}} = status(channel, queue)
    consumer_count
  end

  @doc """
  Returns true if queue is empty (has no messages ready), false otherwise
  """
  def empty?(%Channel{} = channel, queue) do
    message_count(channel, queue) == 0
  end

  @doc false
  def subscribe(%Channel{} = channel, queue, fun) when is_function(fun, 2) do
    {:ok, pid} = AMQP.Queue.Consumer.start_link(channel, queue, fun)
    state = GenServer.call(pid, :state)
    {:ok, state.consumer_tag}
  end

  @doc false
  def unsubscribe(%Channel{} = channel, consumer_tag) do
    Basic.cancel(channel, consumer_tag)
  end
end

defmodule AMQP.Queue.Consumer do
  @moduledoc false

  use AMQP
  use AMQP.Consumer

  def start_link(channel, queue, fun) do
    GenServer.start_link(__MODULE__, [channel, queue, fun])
  end

  def init([channel, queue, fun]) do
    {:ok, consumer_tag} = Basic.consume(channel, queue)
    {:ok, %{channel: channel, queue: queue, consumer_tag: consumer_tag, fun: fun}}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_basic_deliver(payload, meta, state) do
    try do
      state.fun.(payload, meta)
      :ok = Basic.ack(state.channel, meta.delivery_tag)
      {:noreply, state}
    rescue
      exception ->
        stacktrace = System.stacktrace
        Basic.reject(state.channel, meta.delivery_tag, requeue: false)
        reraise exception, stacktrace
    end
  end
end
