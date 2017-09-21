defmodule AMQP.Channel do
  @moduledoc """
  Functions to operate on Channels.
  """

  alias AMQP.{Connection, Channel}

  defstruct [:conn, :pid]
  @type t :: %Channel{conn: Connection.t | nil, pid: pid}

  @doc """
  Opens a new Channel in a previously opened Connection.
  """
  @spec open(Connection.t) :: {:ok, Channel.t} | any
  def open(%Connection{pid: pid} = conn) do
    case :amqp_connection.open_channel(pid) do
      {:ok, chan_pid} -> {:ok, %Channel{conn: conn, pid: chan_pid}}
      error           -> error
    end
  end

  @doc """
  Closes an open Channel.
  """
  @spec close(Channel.t) :: :ok | :closing
  def close(%Channel{pid: pid}) do
    :amqp_channel.close(pid)
  end
end
