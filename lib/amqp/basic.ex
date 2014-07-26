defmodule AMQP.Basic do
  @moduledoc """
  Functions to publish, consume and acknowledge messages.
  """

  require Record
  import AMQP.Core
  alias AMQP.Channel

  Record.defrecordp :amqp_msg, [props: p_basic(), payload: ""]

  @doc """
  Publishes a message to an Exchange.

  This method publishes a message to a specific exchange. The message will be routed to queues as defined by
  the exchange configuration and distributed to any subscribers.

  The parameter `exchange` specifies the name of the exchange to publish to. If set to empty string, it publishes to the
  default exchange.
  The `routing_key` parameter specifies the routing key for the message.

  The `payload` parameter specifies the message content as a binary..

  In addition to the previous parameters, , the following options can be used:

  *   `mandatory`: If set, returns an error if the broker can't route the message to a queue
  *   `immediate`: If set, returns an error if the broker can't deliver te message to a consumer immediately.

  Additional Basic properties can be set using the following options:

  *   `content_type`:   MIME Content type
  *   `content_encoding`:   MIME Content encoding
  *   `headers`:   Message headers. Can be used with headers Exchanges
  *   `persistent`:   If set, uses persistent delivery mode. Messages marked as `persistent` that are delivered to `durable` queues will be logged to disk.
  *   `correlation_id`:   application correlation identifier
  *   `priority`:   message priority, ranging from 0 to 9
  *   `reply_to`:   name of the reply queue
  *   `expiration`:   how long the message is valid (in milliseconds)
  *   `message_id`:   message identifier
  *   `timestamp`:   timestamp associated with this message (epoch time)
  *   `type`:   message type as a string
  *   `user-id`:   creating user ID. RabbitMQ will validate this against the active connection user
  *   `app-id`:  publishing application ID
  """
  def publish(%Channel{pid: pid}, exchange, routing_key, payload, options \\ []) do
    basic_publish =
      basic_publish(exchange:    exchange,
                    routing_key: routing_key,
                    mandatory:   Keyword.get(options, :mandatory, false),
                    immediate:   Keyword.get(options, :immediate, false))
    p_basic =
      p_basic(content_type:     Keyword.get(options, :content_type,     :undefined),
              content_encoding: Keyword.get(options, :content_encoding, :undefined),
              headers:          Keyword.get(options, :headers,          :undefined),
              delivery_mode:    if(options[:persistent], do: 2, else: 1),
              priority:         Keyword.get(options, :priority,         :undefined),
              correlation_id:   Keyword.get(options, :correlation_id,   :undefined),
              reply_to:         Keyword.get(options, :reply_to,         :undefined),
              expiration:       Keyword.get(options, :expiration,       :undefined),
              message_id:       Keyword.get(options, :message_id,       :undefined),
              timestamp:        Keyword.get(options, :timestamp,        :undefined),
              type:             Keyword.get(options, :type,             :undefined),
              user_id:          Keyword.get(options, :user_id,          :undefined),
              app_id:           Keyword.get(options, :app_id,           :undefined),
              cluster_id:       Keyword.get(options, :cluster_id,       :undefined))
    :amqp_channel.cast pid, basic_publish, amqp_msg(props: p_basic, payload: payload)
  end

  @doc """
  Sets the message prefetch count or prefetech size (in bytes). If `global` is set to `true` this
  applies to the entire Connection, otherwise it applies only to the specified Channel.
  """
  def qos(%Channel{pid: pid}, options \\ []) do
    basic_qos_ok() =
      :amqp_channel.call pid,
                         basic_qos(prefetch_size:  Keyword.get(options, :prefetch_size,  0),
                                   prefetch_count: Keyword.get(options, :prefetch_count, 0),
                                   global:         Keyword.get(options, :global,         false))
    :ok
  end

  @doc """
  Acknowledges one or more messages. If multiple is set to `true`, all messages up to the one
  specified by `delivery_tag` are considered acknowledged by the server.
  """
  def ack(%Channel{pid: pid}, delivery_tag, options \\ []) do
    :amqp_channel.call pid, basic_ack(delivery_tag: delivery_tag, multiple: Keyword.get(options, :multiple, false))
  end

  @doc """
  Rejects (and, optionally, requeues) a message.
  """
  def reject(%Channel{pid: pid}, delivery_tag, options \\ []) do
    :amqp_channel.call pid, basic_reject(delivery_tag: delivery_tag,
                                         requeue: Keyword.get(options, :requeue, true))
  end

  @doc """
  Negative acknowledge of one or more messages. If multiple is set to `true`, all messages up to the one
  specified by `delivery_tag` are considered as not acknowledged by the server. If `requeue` is set to
  `true`, the message will be returned to the queue and redelivered the next available consumer.

  This is a RabbitMQ specific extension to AMQP 0.9.1. It is equivalent to reject, but allows rejecting
  multiple messages using the `multiple` option.
  """
  def nack(%Channel{pid: pid}, delivery_tag, options \\ []) do
    :amqp_channel.call pid, basic_nack(delivery_tag: delivery_tag,
                                       multiple: Keyword.get(options, :multiple, false),
                                       requeue: Keyword.get(options, :requeue,   true))
  end

  def get(%Channel{pid: pid}, queue, options \\ []) do
    case :amqp_channel.call pid, basic_get(queue: queue, no_ack: Keyword.get(options, :no_ack, false)) do
      {basic_get_ok(delivery_tag: delivery_tag,
                    redelivered: redelivered,
                    exchange: exchange,
                    routing_key: routing_key,
                    message_count: message_count),
       amqp_msg(props: p_basic(content_type: content_type,
                               content_encoding: content_encoding,
                               headers: headers,
                               delivery_mode: delivery_mode,
                               priority: priority,
                               correlation_id: correlation_id,
                               reply_to: reply_to,
                               expiration: expiration,
                               message_id: message_id,
                               timestamp: timestamp,
                               type: type,
                               user_id: user_id,
                               app_id: app_id,
                               cluster_id: cluster_id), payload: payload)} ->
        {:ok, payload, %{delivery_tag: delivery_tag,
                         redelivered: redelivered,
                         exchange: exchange,
                         routing_key: routing_key,
                         message_count: message_count,
                         content_type: content_type,
                         content_encoding: content_encoding,
                         headers: headers,
                         persistent: delivery_mode == 2,
                         priority: priority,
                         correlation_id: correlation_id,
                         reply_to: reply_to,
                         expiration: expiration,
                         message_id: message_id,
                         timestamp: timestamp,
                         type: type,
                         user_id: user_id,
                         app_id: app_id,
                         cluster_id: cluster_id}}
      basic_get_empty(cluster_id: cluster_id) ->
        {:empty, %{cluster_id: cluster_id}}
    end
  end

  @doc """
  Asks the server to redeliver all unacknowledged messages on a specified channel.

  If `requeue` is set to `true` the server will attempt to requeue the message,
  potentially delivering it to another subscriber. Otherwise it will be redelivered
  to the original recipient.
  """
  def recover(%Channel{pid: pid}, options \\ []) do
    :amqp_channel.call pid, basic_recover(requeue: Keyword.get(options, :requeue, false))
  end

  @doc """
  Registers a queue consumer process. The `pid` of the process can be set using
  the `handler` option and defaults to the calling process.

  The handler process will receive the following data structures and should as
  process messages.
  """
  def consume(%Channel{pid: pid}, queue, options \\ []) do
    basic_consume =
      basic_consume(queue: queue,
                    consumer_tag: Keyword.get(options, :consumer_tag, ""),
                    no_local:     Keyword.get(options, :no_local,     false),
                    no_ack:       Keyword.get(options, :no_ack,       false),
                    exclusive:    Keyword.get(options, :exclusive,    false),
                    nowait:       Keyword.get(options, :no_wait,      false),
                    arguments:    Keyword.get(options, :arguments,    []))

    handler = options[:handler] || self()

    response_mapper = spawn fn ->
      Process.link(handler)
      do_consume(handler)
    end

    basic_consume_ok(consumer_tag: consumer_tag) =
      :amqp_channel.subscribe(pid, basic_consume, response_mapper)

    {:ok, consumer_tag}
  end

  defp do_consume(handler) do
    receive do
      {basic_deliver(consumer_tag: consumer_tag,
                     delivery_tag: delivery_tag,
                     redelivered: redelivered,
                     exchange: exchange,
                     routing_key: routing_key),
       amqp_msg(props: p_basic(content_type: content_type,
                               content_encoding: content_encoding,
                               headers: headers,
                               delivery_mode: delivery_mode,
                               priority: priority,
                               correlation_id: correlation_id,
                               reply_to: reply_to,
                               expiration: expiration,
                               message_id: message_id,
                               timestamp: timestamp,
                               type: type,
                               user_id: user_id,
                               app_id: app_id,
                               cluster_id: cluster_id), payload: payload)} ->
        send handler, {payload, %{consumer_tag: consumer_tag,
                                  delivery_tag: delivery_tag,
                                  redelivered: redelivered,
                                  exchange: exchange,
                                  routing_key: routing_key,
                                  content_type: content_type,
                                  content_encoding: content_encoding,
                                  headers: headers,
                                  persistent: delivery_mode == 2,
                                  priority: priority,
                                  correlation_id: correlation_id,
                                  reply_to: reply_to,
                                  expiration: expiration,
                                  message_id: message_id,
                                  timestamp: timestamp,
                                  type: type,
                                  user_id: user_id,
                                  app_id: app_id,
                                  cluster_id: cluster_id}}
    end
    do_consume(handler)
  end

end