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
  def init({pid, options}) do
    _ref = Process.monitor(pid)
    ignore_shutdown = Keyword.get(options, :ignore_shutdown, false)
    {:ok, %{consumer: pid, ignore_shutdown: ignore_shutdown}}
  end

  def init(pid), do: init({pid, []})

  @impl true
  def handle_consume(basic_consume(), _pid, state) do
    # silently discard
    {:ok, state}
  end

  @impl true
  def handle_consume_ok(method, _args, state) do
    send(state.consumer, compose_message(method))
    {:ok, state}
  end

  @impl true
  def handle_cancel(method, state) do
    send(state.consumer, compose_message(method))
    {:ok, state}
  end

  @impl true
  def handle_cancel_ok(method, _args, state) do
    send(state.consumer, compose_message(method))
    {:ok, state}
  end

  @impl true
  def handle_server_cancel(method, state) do
    send(state.consumer, compose_message(method))
    {:ok, state}
  end

  @impl true
  def handle_deliver(_method, _msg, %{consumer: nil} = _state) do
    {:error, :no_consumer, nil}
  end

  @impl true
  def handle_deliver(method, message, state) do
    send(state.consumer, compose_message(method, message))

    {:ok, state}
  end

  @impl true
  def handle_deliver(_, _args, _ctx, %{consumer: nil} = _state) do
    {:error, :no_consumer, nil}
  end

  @impl true
  def handle_deliver(basic_deliver(), _args, _ctx, _state) do
    # there's no support for direct connection
    # this callback implementation should be added with library support
    {:error, :undefined}
  end

  @impl true
  def handle_info({:DOWN, _mref, :process, state, reason}, %{ignore_shutdown: true} = _state)
      when reason in [:normal, :shutdown] do
    {:ok, Map.put(state, :consumer, nil)}
  end

  def handle_info({:DOWN, _mref, :process, state, :normal}, state) do
    {:ok, state}
  end

  def handle_info({:DOWN, _mref, :process, state, info}, state) do
    {:error, {:consumer_died, info}, state}
  end

  def handle_info(down = {:DOWN, _, _, _, _}, state) do
    send(state.consumer, down)
    {:ok, state}
  end

  def handle_info({basic_return() = method, message}, state) do
    send(state.consumer, compose_message(method, message))

    {:ok, state}
  end

  def handle_info(basic_ack() = method, state) do
    send(state.consumer, compose_message(method))

    {:ok, state}
  end

  def handle_info(basic_nack() = method, state) do
    send(state.consumer, compose_message(method))

    {:ok, state}
  end

  @impl true
  def handle_call({:register_return_handler, chan, _consumer}, _from, state) do
    :amqp_channel.register_return_handler(chan.pid, self())

    {:reply, :ok, state}
  end

  def handle_call({:register_confirm_handler, chan, _consumer}, _from, state) do
    :amqp_channel.register_confirm_handler(chan.pid, self())

    {:reply, :ok, state}
  end

  def handle_call(_req, _from, state) do
    {:reply, {:error, :undefined}, state}
  end

  @impl true
  def terminate(_reason, state), do: state
end
