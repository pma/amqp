defmodule AMQP.DirectConsumer do
  @moduledoc """
  `AMQP.DirectConsumer` is an example custom consumer. It's argument is a pid
  of a process which the channel is meant to forward the messages to.

  ## Usage

      iex> AMQP.Channel.open(conn, {AMQP.DirectConsumer, self()})

  This will forward all the messages from the channel to the calling process.

  This is an Elixir reimplementation of `:amqp_direct_consumer`. (https://github.com/rabbitmq/rabbitmq-erlang-client/blob/master/src/amqp_direct_consumer.erl)

  For more information see:
  https://www.rabbitmq.com/erlang-client-user-guide.html#consumers-imlementation

  ## Caveat

  ### You are recommended to use the default consumer

  AMQP 2.0 comes with an improved version of the default consumer(`AMQP.SelectiveConsumer`).
  There is not an obvious reason using DirectConsumer after the version 2.0.
  We highly recommend you to use the default consumer which lets you decouple
  the consumer concern from the channel.
  If you still want to keep using `DirectConsumer`, keep reading the caveat below.

  ### Close the channel explicitly

  By default, the DirectConsumer detects the user consumer down then...

  * DirectConsumer returns :error in handle_info which results the process to exit.
  * The channel supervisor will detect the DirectConsumer shutdown but the
    restart will be failing as the user consumer is still down.
  * It ends up the channel process to shut down.

  However this is an abnormal shutdown and can cause an unintended race condition.

  To avoid it, make sure to close the channel explicitly and shut down your
  consumer with a `:normal` signal.

  ### Ignore the user consumer shutdown

  DirectConsumer follows the Erlang version and ignores only `:normal` signals
  for the user consumer exit.

  You might want to also ignore `:shutdown` signals as it can also be called
  before the channel is closed.

  You can set the additional reasons to ignore with the following options:

      iex> opts = [ignore_consumer_down: [:normal, :shutdown]]
      iex> AMQP.Channel.open(conn, {AMQP.DirectConsumer, {self(), opts}})

  You can also ignore the user consumer down completely by setting `true` to the value:

      iex> opts = [ignore_consumer_down: true]
      iex> AMQP.Channel.open(conn, {AMQP.DirectConsumer, {self(), opts}})

  """
  import AMQP.Core
  import AMQP.ConsumerHelper
  @behaviour :amqp_gen_consumer
  @default_options [
    ignore_consumer_down: [:normal]
  ]

  #########################################################
  ### amqp_gen_consumer callbacks
  #########################################################

  @impl true
  def init({pid, options}) do
    _ref = Process.monitor(pid)

    options = %{
      ignore_consumer_down: options[:ignore_consumer_down]
    }

    {:ok, %{consumer: pid, options: options}}
  end

  def init(pid), do: init({pid, @default_options})

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

  def handle_deliver(method, message, state) do
    send(state.consumer, compose_message(method, message))

    {:ok, state}
  end

  @impl true
  def handle_deliver(_, _args, _ctx, %{consumer: nil} = _state) do
    {:error, :no_consumer, nil}
  end

  def handle_deliver(basic_deliver(), _args, _ctx, _state) do
    # There's no support for direct connection
    # This callback implementation should be added with library support
    {:error, :undefined}
  end

  @impl true
  def handle_info(
        {:DOWN, _mref, :process, consumer, reason},
        %{consumer: consumer, options: options} = state
      ) do
    if ignore_consumer_down?(reason, options) do
      # Ignores the user consumer DOWN and sets the pid.
      {:ok, Map.put(state, :consumer, nil)}
    else
      # Exit with the same reason.
      {:error, {:consumer_died, reason}, state}
    end
  end

  def handle_info(down = {:DOWN, _, _, _, _}, state) do
    if state.consumer do
      send(state.consumer, down)
    end

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
  def handle_call(
        {:register_return_handler, chan, consumer},
        _from,
        %{consumer: consumer} = state
      ) do
    :amqp_channel.register_return_handler(chan.pid, self())

    {:reply, :ok, state}
  end

  def handle_call(
        {:register_confirm_handler, chan, consumer},
        _from,
        %{consumer: consumer} = state
      ) do
    :amqp_channel.register_confirm_handler(chan.pid, self())

    {:reply, :ok, state}
  end

  def handle_call(_req, _from, state) do
    {:reply, {:error, :undefined}, state}
  end

  @impl true
  def terminate(_reason, state), do: state

  defp ignore_consumer_down?(_reason, %{ignore_consumer_down: true}), do: true

  defp ignore_consumer_down?(reason, %{ignore_consumer_down: reasons}) when is_list(reasons) do
    reason in reasons
  end

  defp ignore_consumer_down?(reason, %{ignore_consumer_down: reason}), do: true
  defp ignore_consumer_down?(_, _), do: false
end
