defmodule AMQP.Confirm do
  @moduledoc """
  Functions that work with publisher confirms (RabbitMQ extension to AMQP 0.9.1).
  """

  import AMQP.Core
  alias AMQP.Channel

  @doc """
  Activates publishing confirmations on the channel.
  """
  def select(%Channel{pid: pid}) do
    confirm_select_ok() = :amqp_channel.call pid, confirm_select()
    :ok
  end

  @doc """
  Wait until all messages published since the last call have been
  either ack'd or nack'd by the broker.
  """
  def wait_for_confirms(%Channel{pid: pid}) do
    :amqp_channel.wait_for_confirms(pid)
  end

  def wait_for_confirms(%Channel{pid: pid}, timeout) do
    :amqp_channel.wait_for_confirms(pid, timeout)
  end

  @doc """
  Wait until all messages published since the last call have been
  either ack'd or nack'd by the broker. If any of the messages
  were nack'd, the calling process dies.
  """
  def wait_for_confirms_or_die(%Channel{pid: pid}) do
    :amqp_channel.wait_for_confirms_or_die(pid)
  end

  def wait_for_confirms_or_die(%Channel{pid: pid}, timeout) do
    :amqp_channel.wait_for_confirms_or_die(pid, timeout)
  end

end
