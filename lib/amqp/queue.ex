defmodule AMQP.Queue do
  @moduledoc """
  Functions to operate on Queues.
  """

  import AMQP.Core

  alias AMQP.{Basic, Channel, Utils, BasicError}

  @doc """
  Declares a queue. The optional `queue` parameter is used to set the name.
  If set to an empty string (default), the server will assign a name.

  Besides the queue name, the following options can be used:

  ## Options

    * `:durable` - If set, keeps the Queue between restarts of the broker
      (default `false`)

    * `:auto_delete` - If set, deletes the Queue once all subscribers
      disconnect (default to `false`)

    * `:exclusive` - If set, only one subscriber can consume from the Queue
      (default `false`)

    * `:passive` - If set, raises an error unless the queue already exists
      (default `false`)

    * `:nowait` - If set, the declare operation is asynchronous (default
      `false`)

    * `:arguments` - A list of arguments to pass when declaring (of type
      `t:AMQP.arguments/0`). See the [README](readme.html) for more information
      (default `[]`)

  """
  @spec declare(Channel.t(), Basic.queue(), keyword) ::
          {:ok, %{queue: Basic.queue(), message_count: integer, consumer_count: integer}}
          | :ok
          | Basic.error()
  def declare(%Channel{pid: pid}, queue \\ "", options \\ []) do
    nowait = get_nowait(options)

    queue_declare =
      queue_declare(
        queue: queue,
        passive: Keyword.get(options, :passive, false),
        durable: Keyword.get(options, :durable, false),
        exclusive: Keyword.get(options, :exclusive, false),
        auto_delete: Keyword.get(options, :auto_delete, false),
        nowait: nowait,
        arguments: Keyword.get(options, :arguments, []) |> Utils.to_type_tuple()
      )

    case {nowait, :amqp_channel.call(pid, queue_declare)} do
      {true, :ok} ->
        :ok

      {_,
       queue_declare_ok(
         queue: queue,
         message_count: message_count,
         consumer_count: consumer_count
       )} ->
        {:ok, %{queue: queue, message_count: message_count, consumer_count: consumer_count}}

      {_, error} ->
        {:error, error}
    end
  end

  @doc """
  Binds a Queue to an Exchange.

  ## Options

    * `:routing_key` - The routing key used to bind the queue to the exchange
      (default `""`)

    * `:nowait` - If `true`, the binding is not synchronous (default `false`)

    * `:arguments` - A list of arguments to pass when binding (of type
      `t:AMQP.arguments/0`).  See the [README](readme.html) for more information
      (default `[]`)

  """
  @spec bind(Channel.t(), Basic.queue(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def bind(%Channel{pid: pid}, queue, exchange, options \\ []) do
    nowait = get_nowait(options)

    queue_bind =
      queue_bind(
        queue: queue,
        exchange: exchange,
        routing_key: Keyword.get(options, :routing_key, ""),
        nowait: nowait,
        arguments: Keyword.get(options, :arguments, []) |> Utils.to_type_tuple()
      )

    case {nowait, :amqp_channel.call(pid, queue_bind)} do
      {true, :ok} -> :ok
      {_, queue_bind_ok()} -> :ok
      {_, error} -> {:error, error}
    end
  end

  @doc """
  Unbinds a Queue from an Exchange.

  ## Options

    * `:routing_key` - The routing queue for removing the binding (default `""`)

    * `:arguments` - A list of arguments to pass when unbinding (of type
      `t:AMQP.arguments/0`).  See the [README](readme.html) for more information
      (defaults `[]`)

  """
  @spec unbind(Channel.t(), Basic.queue(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def unbind(%Channel{pid: pid}, queue, exchange, options \\ []) do
    queue_unbind =
      queue_unbind(
        queue: queue,
        exchange: exchange,
        routing_key: Keyword.get(options, :routing_key, ""),
        arguments: Keyword.get(options, :arguments, [])
      )

    case :amqp_channel.call(pid, queue_unbind) do
      queue_unbind_ok() -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Deletes a Queue by name.

  ## Options

    * `:if_unused` - If set, the server will only delete the queue if it has no
      consumers. If the queue has consumers, it's not deleted and an error is
      returned

    * `:if_empty` - If set, the server will only delete the queue if it has no
      messages

    * `:nowait` - If set, the delete operation is asynchronous

  """
  @spec delete(Channel.t(), Basic.queue(), keyword) :: {:ok, map} | :ok | Basic.error()
  def delete(%Channel{pid: pid}, queue, options \\ []) do
    nowait = get_nowait(options)

    queue_delete =
      queue_delete(
        queue: queue,
        if_unused: Keyword.get(options, :if_unused, false),
        if_empty: Keyword.get(options, :if_empty, false),
        nowait: nowait
      )

    case {nowait, :amqp_channel.call(pid, queue_delete)} do
      {true, :ok} -> :ok
      {_, queue_delete_ok(message_count: message_count)} -> {:ok, %{message_count: message_count}}
      {_, error} -> {:error, error}
    end
  end

  @doc """
  Discards all messages in the Queue.
  """
  @spec purge(Channel.t(), Basic.queue()) :: {:ok, map} | Basic.error()
  def purge(%Channel{pid: pid}, queue) do
    case :amqp_channel.call(pid, queue_purge(queue: queue)) do
      queue_purge_ok(message_count: message_count) -> {:ok, %{message_count: message_count}}
      error -> {:error, error}
    end
  end

  @doc """
  Returns the message count and consumer count for the given queue.
  Uses `declare/3` with the `:passive` option set.
  """
  @spec status(Channel.t(), Basic.queue()) :: {:ok, map} | Basic.error()
  def status(%Channel{} = chan, queue) do
    declare(chan, queue, passive: true)
  end

  @doc """
  Returns the number of messages that are ready for delivery (e.g. not pending
  acknowledgements) in the queue.
  """
  @spec message_count(Channel.t(), Basic.queue()) :: integer | no_return
  def message_count(%Channel{} = channel, queue) do
    case status(channel, queue) do
      {:ok, %{message_count: message_count}} -> message_count
      {:error, reason} -> raise(BasicError, reason: reason)
    end
  end

  @doc """
  Returns a number of active consumers on the queue.
  """
  @spec consumer_count(Channel.t(), Basic.queue()) :: integer | no_return
  def consumer_count(%Channel{} = channel, queue) do
    case status(channel, queue) do
      {:ok, %{consumer_count: consumer_count}} -> consumer_count
      {:error, reason} -> raise(BasicError, reason: reason)
    end
  end

  @doc """
  Returns true if queue is empty (has no messages ready), false otherwise.
  """
  @spec empty?(Channel.t(), Basic.queue()) :: boolean | no_return
  def empty?(%Channel{} = channel, queue) do
    message_count(channel, queue) == 0
  end

  @doc """
  Convenience to consume messages from a Queue.

  The handler function must have arity 2 and will receive as arguments a binary
  with the message payload and a Map with the message properties.

  The consumed message will be acknowledged after executing the handler function.

  If an exception is raised by the handler function, the message is rejected.

  This convenience function will spawn a process and register it using
  `AMQP.Basic.consume/4`.
  """
  @spec subscribe(Channel.t(), Basic.queue(), (String.t(), map -> any), keyword) ::
          {:ok, String.t()} | Basic.error()
  def subscribe(%Channel{} = channel, queue, fun, options \\ []) when is_function(fun, 2) do
    consumer_pid = spawn(fn -> do_start_consumer(channel, fun) end)
    Basic.consume(channel, queue, consumer_pid, options)
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
            Basic.reject(channel, delivery_tag, requeue: false)
            reraise exception, __STACKTRACE__
        end

        do_consume(channel, fun, consumer_tag)

      {:basic_cancel, %{consumer_tag: ^consumer_tag}} ->
        exit(:basic_cancel)

      {:basic_cancel_ok, %{consumer_tag: ^consumer_tag}} ->
        exit(:normal)
    end
  end

  @doc """
  Stops the consumer identified by `consumer_tag` from consuming.

  Internally just calls `AMQP.Basic.cancel/2`.
  """
  @spec unsubscribe(Channel.t(), Basic.consumer_tag()) :: {:ok, String.t()} | Basic.error()
  def unsubscribe(%Channel{} = channel, consumer_tag) do
    Basic.cancel(channel, consumer_tag)
  end

  # support backward compatibility with old key name
  defp get_nowait(opts) do
    Keyword.get(opts, :nowait, false) || Keyword.get(opts, :no_wait, false)
  end
end
