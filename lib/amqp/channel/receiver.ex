defmodule AMQP.Channel.Receiver do
  @moduledoc false

  import AMQP.Core
  alias AMQP.{Basic, Channel, Confirm}
  alias AMQP.Channel.ReceiverManager

  @doc """
  Handles channel messages.
  """
  @spec handle_message(pid(), pid(), map()) :: no_return
  def handle_message(chan_pid, client_pid, handlers) do
    receive do
      {:DOWN, _ref, :process, _pid, reason} ->
        ReceiverManager.unregister_receiver(chan_pid, client_pid)
        handle_message(chan_pid, client_pid, handlers)
        exit(reason)

      {:EXIT, _ref, reason} ->
        ReceiverManager.unregister_receiver(chan_pid, client_pid)
        exit(reason)

      {:add_handler, handler, opts} ->
        new_handlers = add_handler(handlers, handler, opts)
        handle_message(chan_pid, client_pid, new_handlers)

      msg ->
        with true <- Process.alive?(client_pid),
             new_handlers <- do_handle_message(client_pid, handlers, msg),
             size when size > 0 <- map_size(new_handlers) do
          handle_message(chan_pid, client_pid, new_handlers)
        else
          _ -> ReceiverManager.unregister_receiver(chan_pid, client_pid)
        end
    end
  end

  defp add_handler(handlers, :consume, opts) do
    if opts[:tag] do
      consumer_tags = (handlers[:consume] || []) ++ [opts[:tag]]
      Map.put(handlers, :consume, consumer_tags |> Enum.uniq())
    else
      handlers
    end
  end

  defp add_handler(handlers, handler, _) do
    Map.put(handlers, handler, true)
  end

  defp remove_handler(handlers, :consume, opts) do
    if handlers[:consume] && opts[:tag] do
      consumer_tags = List.delete(handlers[:consume], opts[:tag])
      if length(consumer_tags) == 0 do
        Map.delete(handlers, :consume)
      else
        Map.put(handlers, :consume, consumer_tags)
      end
    else
      handlers
    end
  end

  defp remove_handler(handlers, handler, _) do
    Map.delete(handlers, handler)
  end

  defp cancel_handlers(chan_pid, handlers) do
    handlers
    |> Enum.each(fn {handler, value} -> cancel_handler(chan_pid, handler, value) end)
  end

  defp cancel_handler(chan_pid, :confirm, true) do
    Confirm.unregister_handler(%Channel{pid: chan_pid})
  end

  defp cancel_handler(chan_pid, :return, true) do
    Basic.cancel_return(%Channel{pid: chan_pid})
  end

  defp cancel_handler(chan_pid, :consume, tags) do
    chan = %Channel{pid: chan_pid}
    tags
    |> Enum.each(fn consumer_tag ->
      Basic.cancel(chan, consumer_tag)
    end)
  end

  # -- Confirm.register_handler

  defp do_handle_message(client_pid, handlers,
    basic_ack(delivery_tag: delivery_tag, multiple: multiple))
  do
    send(client_pid, {:basic_ack, delivery_tag, multiple})
    handlers
  end

  defp do_handle_message(client_pid, handlers,
    basic_nack(delivery_tag: delivery_tag, multiple: multiple))
  do
    send(client_pid, {:basic_nack, delivery_tag, multiple})
    handlers
  end

  # -- Basic.consume

  defp do_handle_message(client_pid, handlers,
    basic_consume_ok(consumer_tag: consumer_tag))
  do
    send(client_pid, {:basic_consume_ok, %{consumer_tag: consumer_tag}})
    add_handler(handlers, :consume, tag: consumer_tag)
  end

  defp do_handle_message(client_pid, handlers,
    basic_cancel_ok(consumer_tag: consumer_tag))
  do
    send(client_pid, {:basic_cancel_ok, %{consumer_tag: consumer_tag}})
    remove_handler(handlers, :consume, tag: consumer_tag)
  end

  defp do_handle_message(client_pid, handlers,
    basic_cancel(consumer_tag: consumer_tag, nowait: no_wait))
  do
    send(client_pid, {:basic_cancel, %{consumer_tag: consumer_tag, no_wait: no_wait}})
    remove_handler(handlers, :consume, tag: consumer_tag)
  end

  defp do_handle_message(client_pid, handlers, {
    basic_deliver(
      consumer_tag: consumer_tag,
      delivery_tag: delivery_tag,
      redelivered: redelivered,
      exchange: exchange,
      routing_key: routing_key
    ),
    amqp_msg(
      props: p_basic(
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
    )})
  do
    send(client_pid, {:basic_deliver, payload, %{
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
    }})

    handlers
  end

  defp do_handle_message(client_pid, handlers,{
    basic_return(reply_code: reply_code,
                 reply_text: reply_text,
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
                            cluster_id: cluster_id), payload: payload)
    })
  do
    send(client_pid, {:basic_return, payload, %{
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
    }})

    handlers
  end
end
