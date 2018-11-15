defmodule AMQP.Channel do
  @moduledoc """
  Functions to operate on Channels.
  """

  alias AMQP.{Connection, Channel}

  defstruct [:conn, :pid]
  @type t :: %Channel{conn: Connection.t, pid: pid}

  @doc """
  Opens a new Channel in a previously opened Connection.
  """
  @spec open(Connection.t) :: {:ok, Channel.t} | {:error, any}
  def open(%Connection{pid: pid} = conn) do
    case :amqp_connection.open_channel(pid) do
      {:ok, chan_pid} -> {:ok, %Channel{conn: conn, pid: chan_pid}}
      error           -> error
    end
  end

  @doc """
  Closes an open Channel.
  """
  @spec close(Channel.t) :: :ok | {:error, AMQP.Basic.error}
  def close(%Channel{pid: pid}) do
    case :amqp_channel.close(pid) do
      :ok -> :ok
      error -> {:error, error}
    end
  end
end
