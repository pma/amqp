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
  """
  @spec wait_for_confirms(Channel.t()) :: boolean | :timeout
  def wait_for_confirms(%Channel{pid: pid}) do
    :amqp_channel.wait_for_confirms(pid)
  end

  @doc """
  Wait until all messages published since the last call have been either ack'd
  or nack'd by the broker, or until timeout elapses.
  """
  @spec wait_for_confirms(Channel.t(), non_neg_integer) :: boolean | :timeout
  def wait_for_confirms(%Channel{pid: pid}, timeout) do
    :amqp_channel.wait_for_confirms(pid, timeout)
  end

  @doc """
  Wait until all messages published since the last call have been either ack'd
  or nack'd by the broker, or until timeout elapses.

  If any of the messages were nack'd, the calling process dies.
  """
  @spec wait_for_confirms_or_die(Channel.t()) :: true
  def wait_for_confirms_or_die(%Channel{pid: pid}) do
    :amqp_channel.wait_for_confirms_or_die(pid)
  end

  @spec wait_for_confirms_or_die(Channel.t(), non_neg_integer) :: true
  def wait_for_confirms_or_die(%Channel{pid: pid}, timeout) do
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
