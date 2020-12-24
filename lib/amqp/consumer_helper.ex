defmodule AMQP.ConsumerHelper do
  @moduledoc false

  import AMQP.Core

  @doc false
  def compose_message(method, message \\ :undefined)

  def compose_message(basic_consume_ok() = method, _message) do
    body = method |> basic_consume_ok() |> Enum.into(%{})
    {:basic_consume_ok, body}
  end

  def compose_message(basic_cancel_ok() = method, _message) do
    body = method |> basic_cancel_ok() |> Enum.into(%{})
    {:basic_cancel_ok, body}
  end

  def compose_message(basic_cancel() = method, _message) do
    body = method |> basic_cancel() |> Enum.into(%{})
    {:basic_cancel, body}
  end

  def compose_message(basic_credit_drained() = method, _message) do
    body = method |> basic_credit_drained() |> Enum.into(%{})
    {:basic_credit_drained, body}
  end

  def compose_message(
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

  def compose_message(
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

  def compose_message(basic_ack(delivery_tag: delivery_tag, multiple: multiple), _message) do
    {:basic_ack, delivery_tag, multiple}
  end

  def compose_message(basic_nack(delivery_tag: delivery_tag, multiple: multiple), _message) do
    {:basic_nack, delivery_tag, multiple}
  end
end
