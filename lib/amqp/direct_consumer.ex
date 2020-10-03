defmodule AMQP.DirectConsumer do
  @moduledoc """
    `AMQP.DirectConsumer` is an example custom consumer. It's argument is a pid of a process which the channel is
    meant to forward the messages to.

    When using the `DirectConsumer` the channel will forward the messages directly to the specified pid, as well as monitor
    that pid, so that when it exits the channel will exit as well (closing the channel).

    ## Usage

        iex> AMQP.Channel.open(conn, {AMQP.DirectConsumer, self()})

    This will forward all the messages from the channel to the calling process.

    This is an Elixir reimplementation of `:amqp_direct_consumer`. ( https://github.com/rabbitmq/rabbitmq-erlang-client/blob/master/src/amqp_direct_consumer.erl)
    For more information see: https://www.rabbitmq.com/erlang-client-user-guide.html#consumers-imlementation
  """
  import AMQP.Core
  @behaviour :amqp_gen_consumer

  #########################################################
  ### amqp_gen_consumer callbacks
  #########################################################

  @impl true
  def init(consumer) do
    _ref = Process.monitor(consumer)
    {:ok, consumer}
  end

  @impl true
  def handle_consume(basic_consume(), _pid, consumer) do
    # silently discard
    {:ok, consumer}
  end

  @impl true
  def handle_consume_ok(basic_consume_ok(consumer_tag: consumer_tag), _args, consumer) do
    _ = send(consumer, {:basic_consume_ok, %{consumer_tag: consumer_tag}})
    {:ok, consumer}
  end

  @impl true
  def handle_cancel(basic_cancel(consumer_tag: consumer_tag, nowait: no_wait), consumer) do
    _ = send(consumer, {:basic_cancel, %{consumer_tag: consumer_tag, no_wait: no_wait}})
    {:ok, consumer}
  end

  @impl true
  def handle_cancel_ok(basic_cancel_ok(consumer_tag: consumer_tag), _args, consumer) do
    _ = send(consumer, {:basic_cancel_ok, %{consumer_tag: consumer_tag}})
    {:ok, consumer}
  end

  @impl true
  def handle_server_cancel(basic_cancel(consumer_tag: consumer_tag, nowait: no_wait), consumer) do
    _ = send(consumer, {:basic_cancel, %{consumer_tag: consumer_tag, no_wait: no_wait}})
    {:ok, consumer}
  end

  @impl true
  def handle_deliver(
        basic_deliver(
          consumer_tag: consumer_tag,
          delivery_tag: delivery_tag,
          redelivered: redelivered,
          exchange: exchange,
          routing_key: routing_key
        ),
        amqp_msg(
          props:
            p_basic(
              content_type: content_type,
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
              cluster_id: cluster_id
            ),
          payload: payload
        ),
        consumer
      ) do
    send(
      consumer,
      {:basic_deliver, payload,
       %{
         consumer_tag: consumer_tag,
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
         cluster_id: cluster_id
       }}
    )

    {:ok, consumer}
  end

  @impl true
  def handle_deliver(basic_deliver(), _args, _ctx, _consumer) do
    # there's no support for direct connection
    # this callback implementation should be added with library support
    {:error, :undefined}
  end

  @impl true
  def handle_info({:DOWN, _mref, :process, consumer, :normal}, consumer) do
    {:ok, consumer}
  end

  def handle_info({:DOWN, _mref, :process, consumer, info}, consumer) do
    {:error, {:consumer_died, info}, consumer}
  end

  def handle_info(down = {:DOWN, _, _, _, _}, consumer) do
    _ = send(consumer, down)
    {:ok, consumer}
  end

  @impl true
  def handle_call(_req, _from, consumer) do
    {:reply, {:error, :undefined}, consumer}
  end

  @impl true
  def terminate(_reason, consumer), do: consumer
end
