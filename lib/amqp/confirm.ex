defmodule AMQP.Confirm do
  @moduledoc """
  Functions that work with publisher confirms (RabbitMQ extension to AMQP 0.9.1).
  """

  import AMQP.Core
  alias AMQP.{Basic, Channel}

  @doc """
  Activates publishing confirmations on the channel.
  """
  @spec select(Channel.t) :: :ok | Basic.error
  def select(%Channel{pid: pid}) do
    case :amqp_channel.call(pid, confirm_select()) do
      confirm_select_ok() -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Wait until all messages published since the last call have been
  either ack'd or nack'd by the broker.
  """
  @spec wait_for_confirms(Channel.t) :: boolean | :timeout
  def wait_for_confirms(%Channel{pid: pid}) do
    :amqp_channel.wait_for_confirms(pid)
  end

  @doc """
  Wait until all messages published since the last call have been
  either ack'd or nack'd by the broker, or until timeout elapses.
  """
  @spec wait_for_confirms(Channel.t, non_neg_integer) :: boolean | :timeout
  def wait_for_confirms(%Channel{pid: pid}, timeout) do
    :amqp_channel.wait_for_confirms(pid, timeout)
  end

  @doc """
  Wait until all messages published since the last call have been
  either ack'd or nack'd by the broker, or until timeout elapses.
  If any of the messages were nack'd, the calling process dies.
  """
  @spec wait_for_confirms_or_die(Channel.t) :: true
  def wait_for_confirms_or_die(%Channel{pid: pid}) do
    :amqp_channel.wait_for_confirms_or_die(pid)
  end

  @spec wait_for_confirms_or_die(Channel.t, non_neg_integer) :: true
  def wait_for_confirms_or_die(%Channel{pid: pid}, timeout) do
    :amqp_channel.wait_for_confirms_or_die(pid, timeout)
  end
end
