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

  ## Options
    - custom_consumer -- `t:custom_consumer/0` implementation. The consumer
                          must implement the `:amqp_gen_consumer` behavior from `:amqp_client`. See
                         `:amqp_connection.open_channel/2` for more details and
                         `AMQP.DirectConsumer` for an example of a custom consumer.

    - channel_number  -- the number to use for the channel number. This is not recommended to set manually. See
                         `:amqp_connection.open_channel/3` for more information.
  """
  @spec open(Connection.t(), keyword() | custom_consumer()) :: {:ok, Channel.t()} | {:error, any}
  def open(conn, opts \\ [])

  def open(%Connection{} = conn, opts) when is_list(opts) do
    consumer = Keyword.get(opts, :custom_consumer, {SelectiveConsumer, self()})

    if channel_number = Keyword.get(opts, :channel_number) do
      do_open_channel(conn, channel_number, consumer)
    else
      do_open_channel(conn, consumer)
    end
  end

  def open(%Connection{} = conn, custom_consumer) when is_tuple(custom_consumer) do
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

  defp do_open_channel(conn, channel_number, custom_consumer) do
    case :amqp_connection.open_channel(conn.pid, channel_number, custom_consumer) do
      {:ok, chan_pid} ->
        {:ok, %Channel{conn: conn, pid: chan_pid, custom_consumer: custom_consumer}}

      error ->
        {:error, error}
    end
  end
end
