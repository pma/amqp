defmodule AMQP.Channel do
  @moduledoc """
  Functions to operate on Channels.
  """

  alias AMQP.{Connection, Channel}

  defstruct [:conn, :pid, :consumer_type]
  @type t :: %Channel{conn: Connection.t(), pid: pid, consumer_type: consumer_type}
  @type consumer_type :: :direct | :selective
  @type opts :: [consumer_type: consumer_type, consumer_module: module, consumer_init_args: any]

  @doc """
  Opens a new Channel in a previously opened Connection.

  ## Options
    * `:consumer_type` - specifies the type of consumer used as callback module.
      available options: `:selective` or `:direct`. Defaults to `:selective`;
    * `:consumer_module` - specifies consumer callback module. Used only with `:consumer_type: :direct` \
      ignored otherwise. Defaults to `AMQP.Channel.DirectReceiver`;
    * `:consumer_init_args` - arguments that will be passed to `init/1` function of
      consumer callback module. Used only with `:consumer_type: :direct` ignored otherwise. \
      If used with default `:consumer_module` it expects `t:Process.dest/0` of process \
      receiving AMQP messages. Defaults to caller `pid`.
  """
  @spec open(Connection.t(), opts) :: {:ok, Channel.t()} | {:error, any}
  def open(%Connection{} = conn, opts \\ []) do
    consumer_type = Keyword.get(opts, :consumer_type, :selective)
    do_open_channel(conn, consumer_type, opts)
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

  defp do_open_channel(conn, type = :selective, _opts) do
    case :amqp_connection.open_channel(conn.pid) do
      {:ok, chan_pid} -> {:ok, %Channel{consumer_type: type, conn: conn, pid: chan_pid}}
      error -> error
    end
  end

  defp do_open_channel(conn, type = :direct, opts) do
    consumer_module = Keyword.get(opts, :consumer_module, AMQP.Channel.DirectReceiver)
    consumer_init_args = Keyword.get(opts, :consumer_init_args, self())

    case :amqp_connection.open_channel(conn.pid, {consumer_module, consumer_init_args}) do
      {:ok, chan_pid} -> {:ok, %Channel{consumer_type: type, conn: conn, pid: chan_pid}}
      error -> error
    end
  end
end
