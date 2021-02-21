defmodule AMQP.Channel do
  @moduledoc """
  Functions to operate on Channels.
  """

  alias AMQP.{Connection, Channel, SelectiveConsumer}

  defstruct [:conn, :pid, :custom_consumer]
  @type t :: %Channel{conn: Connection.t(), pid: pid, custom_consumer: custom_consumer() | nil}
  @type custom_consumer :: {module(), args :: any()}

  @doc """
  Opens a new Channel in a previously opened Connection.

  Allows optionally to pass a `t:custom_consumer/0` to start a custom consumer
  implementation. The consumer must implement the `:amqp_gen_consumer` behavior
  from `:amqp_client`. See `:amqp_connection.open_channel/2` for more details
  and `AMQP.DirectConsumer` for an example of a custom consumer.
  """
  @spec open(Connection.t(), custom_consumer | nil) :: {:ok, Channel.t()} | {:error, any}
  def open(%Connection{} = conn, custom_consumer \\ {SelectiveConsumer, self()}) do
    do_open_channel(conn, custom_consumer)
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
      error -> {:error, error}
    end
  end

  defp do_open_channel(conn, custom_consumer) do
    case :amqp_connection.open_channel(conn.pid, custom_consumer) do
      {:ok, chan_pid} ->
        {:ok, %Channel{conn: conn, pid: chan_pid, custom_consumer: custom_consumer}}

      error ->
        {:error, error}
    end
  end
end
