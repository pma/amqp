defmodule AMQP.Channel do
  @moduledoc """
  Functions to operate on Channels.
  """

  alias AMQP.Connection
  alias AMQP.Channel

  defstruct [:conn, :pid]
  @type t :: %AMQP.Channel{conn: AMQP.Connection.t, pid: pid}

  @doc """
  Opens a new Channel in a previously opened Connection.
  """
  def open(%Connection{pid: pid} = conn) do
    case :amqp_connection.open_channel(pid) do
      {:ok, chan_pid} -> {:ok, %Channel{conn: conn, pid: chan_pid}}
      error           -> error
    end
  end

  @doc """
  Closes an open Channel.
  """
  def close(%Channel{pid: pid}) do
    :amqp_channel.close(pid)
  end
end
