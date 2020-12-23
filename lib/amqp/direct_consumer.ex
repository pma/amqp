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
  import AMQP.ConsumerHelper
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
  def handle_consume_ok(method, _args, consumer) do
    send(consumer, compose_message(method))
    {:ok, consumer}
  end

  @impl true
  def handle_cancel(method, consumer) do
    send(consumer, compose_message(method))
    {:ok, consumer}
  end

  @impl true
  def handle_cancel_ok(method, _args, consumer) do
    send(consumer, compose_message(method))
    {:ok, consumer}
  end

  @impl true
  def handle_server_cancel(method, consumer) do
    send(consumer, compose_message(method))
    {:ok, consumer}
  end

  @impl true
  def handle_deliver(method, message, consumer) do
    send(consumer, compose_message(method, message))

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
    send(consumer, down)
    {:ok, consumer}
  end

  def handle_info({basic_return() = method, message}, consumer) do
    send(consumer, compose_message(method, message))

    {:ok, consumer}
  end

  def handle_info(basic_ack() = method, consumer) do
    send(consumer, compose_message(method))

    {:ok, consumer}
  end

  def handle_info(basic_nack() = method, consumer) do
    send(consumer, compose_message(method))

    {:ok, consumer}
  end

  @impl true
  def handle_call({:register_return_handler, chan, consumer}, _from, consumer) do
    :amqp_channel.register_return_handler(chan.pid, self())

    {:reply, :ok, consumer}
  end

  def handle_call({:register_confirm_handler, chan, consumer}, _from, consumer) do
    :amqp_channel.register_confirm_handler(chan.pid, self())

    {:reply, :ok, consumer}
  end


  def handle_call(_req, _from, consumer) do
    {:reply, {:error, :undefined}, consumer}
  end

  @impl true
  def terminate(_reason, consumer), do: consumer
end
