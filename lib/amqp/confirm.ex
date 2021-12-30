defmodule AMQP.Confirm do
  @moduledoc """
  Functions that work with publisher confirms (RabbitMQ extension to AMQP
  0.9.1).
  """

  import AMQP.Core
  alias AMQP.{Basic, Channel}

  @doc """
  Activates publishing confirmations on the channel.
  """
  @spec select(Channel.t()) :: :ok | Basic.error()
  def select(%Channel{pid: pid}) do
    case :amqp_channel.call(pid, confirm_select()) do
      confirm_select_ok() -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Wait until all messages published since the last call have been either ack'd
  or nack'd by the broker.

  Same as `wait_for_confirms/2` but with the default timeout of 60 seconds.
  """
  @spec wait_for_confirms(Channel.t()) :: boolean | :timeout
  def wait_for_confirms(%Channel{pid: pid}) do
    :amqp_channel.wait_for_confirms(pid)
  end

  defguardp is_int_timeout(timeout) when is_integer(timeout) and timeout >= 0

  # The typespec for this timeout is:
  # non_neg_integer() | {non_neg_integer(), :second | :millisecond}
  defguardp is_wait_for_confirms_timeout(timeout)
            when is_int_timeout(timeout) or
                   (is_tuple(timeout) and tuple_size(timeout) == 2 and
                      is_int_timeout(elem(timeout, 0)) and
                      elem(timeout, 1) in [:second, :millisecond])

  @doc """
  Wait until all messages published since the last call have been either ack'd
  or nack'd by the broker, or until timeout elapses.

  Returns `true` if all messages are ack'd. Returns `false` if *any* of the messages
  are nack'd. Returns `:timeout` on timeouts.

  `timeout` can be an integer or a tuple with the "time unit" (see the spec). If just an integer
  is provided, it's assumed to be *in seconds*. This is unconventional Elixir/Erlang API
  (since usually the convention is milliseconds), but we are forwarding to the underlying
  AMQP Erlang library here and it would be a breaking change for this library to default
  to milliseconds.
  """
  @spec wait_for_confirms(
          Channel.t(),
          non_neg_integer | {non_neg_integer, :second | :millisecond}
        ) :: boolean | :timeout
  def wait_for_confirms(%Channel{pid: pid}, timeout) when is_wait_for_confirms_timeout(timeout) do
    :amqp_channel.wait_for_confirms(pid, timeout)
  end

  @doc """
  Wait until all messages published since the last call have been either ack'd
  or nack'd by the broker, or until timeout elapses.

  If any of the messages were nack'd, the calling process dies.

  Same as `wait_for_confirms_or_die/2` but with the default timeout of 60 seconds.
  """
  @spec wait_for_confirms_or_die(Channel.t()) :: true
  def wait_for_confirms_or_die(%Channel{pid: pid}) do
    :amqp_channel.wait_for_confirms_or_die(pid)
  end

  @spec wait_for_confirms_or_die(
          Channel.t(),
          non_neg_integer | {non_neg_integer, :second | :millisecond}
        ) :: true
  def wait_for_confirms_or_die(%Channel{pid: pid}, timeout)
      when is_wait_for_confirms_timeout(timeout) do
    :amqp_channel.wait_for_confirms_or_die(pid, timeout)
  end

  @doc """
  On channel with confirm activated, return the next message sequence number.

  To use in combination with `register_handler/2`
  """
  @spec next_publish_seqno(Channel.t()) :: non_neg_integer
  def next_publish_seqno(%Channel{pid: pid}) do
    :amqp_channel.next_publish_seqno(pid)
  end

  @doc """
  Register a handler for confirms on channel.

  The handler will receive either:

    * `{:basic_ack, seqno, multiple}`

    * `{:basic_nack, seqno, multiple}`

  The `seqno` (delivery_tag) is an integer, the sequence number of the message.

  `multiple` is a boolean, when `true` means multiple messages confirm, up to
  `seqno`.

  See https://www.rabbitmq.com/confirms.html
  """
  @spec register_handler(Channel.t(), pid) :: :ok
  def register_handler(%Channel{} = chan, handler_pid) do
    :amqp_channel.call_consumer(chan.pid, {:register_confirm_handler, chan, handler_pid})
  end

  @doc """
  Remove the return handler.

  It does nothing if there is no such handler.
  """
  @spec unregister_handler(Channel.t()) :: :ok
  def unregister_handler(%Channel{pid: pid}) do
    # Currently we don't remove the receiver.
    # The receiver will be deleted automatically when channel is closed.
    :amqp_channel.unregister_confirm_handler(pid)
  end
end
