defmodule AMQP.Channel do
  @moduledoc """
  Functions to operate on Channels.
  """

  alias AMQP.{Connection, Channel}

  defstruct [:conn, :pid, :consumer_spec]
  @type t :: %Channel{conn: Connection.t(), pid: pid, consumer_spec: consumer_spec()}
  @type consumer_spec :: {module(), args :: any()}

  @doc """
  Opens a new Channel in a previously opened Connection.

  Allows optionally to pass a `t:consumer_spec/0` to start a custom consumer implementation. The
  consumer must implement the `:amqp_gen_consumer` behavior from `:amqp_client`. See
  `:amqp_connection.open_channel/2` for more details.
  """
  @spec open(Connection.t(), consumer_spec | nil) :: {:ok, Channel.t()} | {:error, any}
  def open(%Connection{} = conn, consumer_spec \\ nil) do
    do_open_channel(conn, consumer_spec)
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

  defp do_open_channel(conn, nil) do
    case :amqp_connection.open_channel(conn.pid) do
      {:ok, chan_pid} -> {:ok, %Channel{conn: conn, pid: chan_pid}}
      error -> error
    end
  end

  defp do_open_channel(conn, consumer_spec) do
    case :amqp_connection.open_channel(conn.pid, consumer_spec) do
      {:ok, chan_pid} -> {:ok, %Channel{conn: conn, pid: chan_pid, consumer_spec: consumer_spec}}
      error -> error
    end
  end
end
