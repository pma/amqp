defmodule AMQP.Queue do
  @moduledoc """
  Functions to operate on Queues.
  """

  import AMQP.Core

  alias AMQP.Channel
  alias AMQP.Basic
  alias AMQP.Utils

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
                    arguments:   Keyword.get(options, :arguments,   []) |> Utils.to_type_tuple)
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
                 arguments:   Keyword.get(options, :arguments,   []) |> Utils.to_type_tuple)
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

  @doc """
  Convenience to consume messages from a Queue.

  The handler function must have arity 2 and will receive as arguments a binary with the message payload
  and a Map with the message properties.

  The consumed message will be acknowledged after executing the handler function.
  If an exception is raised by the handler function, the message is rejected.

  This convenience function will spawn a process and register it using AMQP.Basic.consume.
  """
  def subscribe(%Channel{} = channel, queue, fun) when is_function(fun, 2) do
    consumer_pid = spawn fn -> do_start_consumer(channel, fun) end
    Basic.consume(channel, queue, consumer_pid)
  end

  defp do_start_consumer(channel, fun) do
    receive do
      {:basic_consume_ok, %{consumer_tag: consumer_tag}} ->
        do_consume(channel, fun, consumer_tag)
    end
  end

  defp do_consume(channel, fun, consumer_tag) do
    receive do
      {:basic_deliver, payload, %{delivery_tag: delivery_tag} = meta} ->
        try do
          fun.(payload, meta)
          Basic.ack(channel, delivery_tag)
        rescue
          exception ->
            stacktrace = System.stacktrace
            Basic.reject(channel, delivery_tag, requeue: false)
            reraise exception, stacktrace
        end
        do_consume(channel, fun, consumer_tag)
      {:basic_cancel, %{consumer_tag: ^consumer_tag, no_wait: _}} ->
        exit(:basic_cancel)
      {:basic_cancel_ok, %{consumer_tag: ^consumer_tag}} ->
        exit(:normal)
    end
  end

  @doc """
  Convenience to end a Queue consumer.
  """
  def unsubscribe(%Channel{} = channel, consumer_tag) do
    Basic.cancel(channel, consumer_tag)
  end
end
