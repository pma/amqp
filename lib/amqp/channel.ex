defmodule AMQP.Channel do
  @moduledoc """
  Functions to operate on Channels.
  """

  alias AMQP.{Connection, Channel}

  defstruct [:conn, :pid, :consumer_type]
  @type t :: %Channel{conn: Connection.t(), pid: pid, consumer_type: consumer_type}
  @typep consumer_type :: :direct | :selective
  @typep opts :: [consumer_type: consumer_type, consumer_pid: pid]

  @doc """
  Opens a new Channel in a previously opened Connection.

  ## Options
    * `:consumer_type` - specifies the type of consumer used as callback module.
      available options: `:selective` or `:direct`. Defaults to `:selective`
    * `:consumer_pid` - let you customize pid of process receiving amqp messages.
      Defaults to process calling the function. Used only in combination with  \
      `consumer_type: :direct`. Ignored otherwise.
  """
  @spec open(Connection.t(), opts) :: {:ok, Channel.t()} | {:error, any}
  def open(%Connection{} = conn, opts \\ []) do
    consumer_type = Keyword.get(opts, :consumer_type, :selective)
    consumer_pid = Keyword.get(opts, :consumer_pid, self())
    do_open_channel(conn, consumer_type, consumer_pid)
  end

  @doc """
  Closes an open Channel.
  """
  @spec close(Channel.t()) :: :ok | {:error, AMQP.Basic.error()}
  def close(%Channel{pid: pid}) do
    case :amqp_channel.close(pid) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  defp do_open_channel(conn, :selective, _) do
    case :amqp_connection.open_channel(conn.pid) do
      {:ok, chan_pid} -> {:ok, %Channel{consumer_type: :selective, conn: conn, pid: chan_pid}}
      error -> error
    end
  end

  defp do_open_channel(conn, :direct, pid) do
    case :amqp_connection.open_channel(conn.pid, {AMQP.Channel.DirectReceiver, [pid]}) do
      {:ok, chan_pid} -> {:ok, %Channel{consumer_type: :direct, conn: conn, pid: chan_pid}}
      error -> error
    end
  end
end
