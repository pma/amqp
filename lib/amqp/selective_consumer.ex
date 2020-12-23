defmodule AMQP.SelectiveConsumer do
  @moduledoc """
  TODO
  """
  import AMQP.Core
  alias AMQP.{Channel, SelectiveConsumer}
  @behaviour :amqp_gen_consumer

  defstruct consumers: %{}, unassigned: :undefined, monitors: %{}, default_consumer: :none, return_handler: :none, confirm_handler: :none

  @type t :: %SelectiveConsumer{
          consumers: %{String.t() => pid},
          unassigned: pid | :undefined,
          monitors: %{pid => {integer, reference}},
          default_consumer: pid | :none,
          return_handler: pid | :none
        }

  @doc """
  Ported from :amqp_selective_consumer.register_default_consumer/2.

  This function registers a default consumer with the channel.
  A default consumer is used when a subscription is made via
  amqp_channel:call(ChannelPid, #'basic.consume'{}) (rather than {@module}:subscribe/3) and
  hence there is no consumer pid registered with the consumer tag. In this case, the relevant
  deliveries will be sent to the default consumer.
  """
  @spec register_default_consumer(Channel.t(), pid) :: :ok
  def register_default_consumer(%Channel{pid: pid}, consumer_pid) do
    :amqp_channel.call_consumer(pid, {:register_default_consumer, consumer_pid})
  end

  @impl true
  def init(_state) do
    {:ok, %SelectiveConsumer{}}
  end

  @impl true
  def handle_consume(basic_consume(consumer_tag: tag, nowait: nowait), pid, status) do
    result =
      case nowait do
        true when tag == :undefined or is_nil(tag) or byte_size(tag) == 0 ->
          :no_consumer_tag_specified

        _ when is_binary(tag) and byte_size(tag) >= 0 ->
          case resolve_consumer(tag, status) do
            {:consumer, _} -> :consumer_tag_in_use
            _ -> :ok
          end

        _ ->
          :ok
      end

    case {result, nowait} do
      {:ok, true} ->
        c = Map.put(status.consumers, tag, pid)
        m = add_to_monitors(status.monitors, pid)
        {:ok, %{status | consumers: c, monitors: m}}

      {:ok, false} ->
        {:ok, %{status | unassigned: pid}}

      {error, true} ->
        {:error, error, status}

      {_error, false} ->
        # Don't do anything (don't override existing consumers), the server will close the channel with an error.
        {:ok, status}
    end
  end

  @impl true
  def handle_consume_ok(
        basic_consume_ok(consumer_tag: tag) = consume_ok,
        _consume,
        %{unassigned: pid} = status
      )
      when is_pid(pid) do
    c = Map.put(status.consumers, tag, pid)
    m = add_to_monitors(status.monitors, pid)

    status = %{status | consumers: c, monitors: m, unassigned: :undefined}
    {:ok, %{status | consumers: c, monitors: m}}

    deliver(consume_ok, status)

    {:ok, status}
  end

  @impl true
  def handle_cancel(basic_cancel(nowait: true), %{default_consumer: :none}) do
    exit(:cancel_nowait_requires_default_consumer)
  end

  def handle_cancel(basic_cancel(nowait: nowait) = cancel, status) do
    case nowait do
      true -> {:ok, do_cancel(cancel, status)}
      false -> {:ok, status}
    end
  end

  defp do_cancel(cancel, status) do
    tag = tag(cancel)

    case Map.fetch(status.consumers, tag) do
      {:ok, consumer} ->
        c = Map.delete(status.consumers, tag)
        m = remove_from_monitors(status.monitors, consumer)
        %{status | consumers: c, monitors: m}

      _error ->
        # untracked consumer
        status
    end
  end

  @impl true
  def handle_cancel_ok(basic_cancel_ok() = cancel_ok, _cancel, status) do
    new_status = do_cancel(cancel_ok, status)
    # use old status
    deliver(cancel_ok, status)

    {:ok, new_status}
  end

  @impl true
  def handle_server_cancel(basic_cancel(nowait: true) = cancel, status) do
    new_status = do_cancel(cancel, status)
    # use old status
    deliver(cancel, status)

    {:ok, new_status}
  end

  @impl true
  def handle_deliver(method, message, status) do
    deliver(method, message, status)
    {:ok, status}
  end

  @impl true
  def handle_deliver(_method, _message, _delivery_ctx, _status) do
    # The handler is called with delivery_ctx for direct connection.
    # Since the library is not supporting direct connection, returns an error.
    #
    # deliver(method, message, delivery_ctx, status)
    # {:ok, status}

    {:error, :undefined}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, status) do
    m = Map.delete(status.monitors, pid)
    d = if status.default_consumer == pid, do: :none, else: status.default_consumer
    c = status.consumers |> Enum.reject(fn {_, v} -> v == pid end) |> Map.new()

    {:ok, %{status | consumers: c, monitors: m, default_consumer: d}}
  end

  def handle_info(basic_credit_drained() = method, status) do
    deliver(method, status)
    {:ok, status}
  end

  def handle_info({basic_return() = method, message}, %{return_handler: pid} = status) when is_pid(pid) do
    composed = compose_message(method, message)
    send(pid, composed)

    {:ok, status}
  end

  def handle_info(basic_ack() = method, %{confirm_handler: pid} = status) when is_pid(pid) do
    composed = compose_message(method, :undefined)
    send(pid, composed)

    {:ok, status}
  end

  def handle_info(basic_nack() = method, %{confirm_handler: pid} = status) when is_pid(pid) do
    composed = compose_message(method, :undefined)
    send(pid, composed)

    {:ok, status}
  end

  @impl true
  def handle_call({:register_default_consumer, pid}, _from, status) do
    m =
      if is_pid(status.default_consumer) do
        remove_from_monitors(status.monitors, status.default_consumer)
      else
        status.monitors
      end
      |> add_to_monitors(pid)

    {:reply, :ok, %{status | monitors: m, default_consumer: pid}}
  end

  def handle_call({:register_return_handler, chan, handler_pid}, _from, status) do
    :amqp_channel.register_return_handler(chan.pid, self())

    {:reply, :ok, %{status | return_handler: handler_pid}}
  end

  def handle_call({:register_confirm_handler, chan, handler_pid}, _from, status) do
    :amqp_channel.register_confirm_handler(chan.pid, self())

    {:reply, :ok, %{status | confirm_handler: handler_pid}}
  end

  @impl true
  def terminate(_reason, _status) do
    :ok
  end

  defp deliver(method, status) do
    deliver(method, :undefined, status)
  end

  defp deliver(method, message, status) do
    tag = tag(method)
    composed = compose_message(method, message)
    deliver_to_consumer_or_die(tag, composed, status)
  end

  # delivery_ctx support is yet to come.
  #
  # defp deliver(method, message, delivery_ctx, status) do
  #   tag = tag(method)
  #   composed =
  #     method
  #     |> compose_message(message)
  #     |> Tuple.append(delivery_ctx)
  #
  #   deliver_to_consumer_or_die(tag, composed, status)
  # end

  defp deliver_to_consumer_or_die(tag, message, status) do
    case resolve_consumer(tag, status) do
      {:consumer, pid} -> send(pid, message)
      {:default, pid} -> send(pid, message)
      _error -> exit(:unexpected_delivery_and_no_default_consumer)
    end
  end

  # AMQP original: convert Erlang record to map
  defp compose_message(basic_consume_ok() = method, _message) do
    body = method |> basic_consume_ok() |> Enum.into(%{})
    {:basic_consume_ok, body}
  end

  defp compose_message(basic_cancel_ok() = method, _message) do
    body = method |> basic_cancel_ok() |> Enum.into(%{})
    {:basic_cancel_ok, body}
  end

  defp compose_message(basic_cancel() = method, _message) do
    body = method |> basic_cancel() |> Enum.into(%{})
    {:basic_cancel, body}
  end

  defp compose_message(basic_credit_drained() = method, _message) do
    body = method |> basic_credit_drained() |> Enum.into(%{})
    {:basic_credit_drained, body}
  end

  defp compose_message(
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
         )
       ) do
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
  end

  defp compose_message(
          basic_return(
           reply_code: reply_code,
           reply_text: reply_text,
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
         )
        ) do
    {:basic_return, payload,
     %{
       reply_code: reply_code,
       reply_text: reply_text,
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
  end

  defp compose_message(basic_ack(delivery_tag: delivery_tag, multiple: multiple), _message) do
    {:basic_ack, delivery_tag, multiple}
  end

  defp compose_message(basic_nack(delivery_tag: delivery_tag, multiple: multiple), _message) do
    {:basic_nack, delivery_tag, multiple}
  end

  defp resolve_consumer(tag, %{consumers: consumers, default_consumer: default}) do
    case Map.fetch(consumers, tag) do
      {:ok, pid} ->
        {:consumer, pid}

      :error when is_pid(default) ->
        {:default, default}

      _ ->
        :error
    end
  end

  defp add_to_monitors(monitors, pid) do
    case Map.fetch(monitors, pid) do
      :error ->
        Map.put(monitors, pid, {1, :erlang.monitor(:process, pid)})

      {:ok, {count, mref}} ->
        Map.put(monitors, pid, {count + 1, mref})
    end
  end

  defp remove_from_monitors(monitors, pid) do
    case Map.fetch(monitors, pid) do
      {:ok, {1, mref}} ->
        :erlang.demonitor(mref)
        Map.delete(monitors, pid)

      {:ok, {count, mref}} ->
        Map.put(monitors, pid, {count - 1, mref})
    end
  end

  defp tag(basic_consume(consumer_tag: tag)), do: tag
  defp tag(basic_consume_ok(consumer_tag: tag)), do: tag
  defp tag(basic_cancel(consumer_tag: tag)), do: tag
  defp tag(basic_cancel_ok(consumer_tag: tag)), do: tag
  defp tag(basic_deliver(consumer_tag: tag)), do: tag
  defp tag(basic_credit_drained(consumer_tag: tag)), do: tag
end