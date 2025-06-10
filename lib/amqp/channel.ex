defmodule AMQP.Channel do
  @moduledoc """
  Functions to operate on Channels.
  """

  alias AMQP.{Connection, Channel, SelectiveConsumer}

  defstruct [:conn, :pid, :custom_consumer]

  @type t :: %Channel{
          conn: Connection.t(),
          pid: pid,
          channel_number: channel_number() | nil,
          custom_consumer: custom_consumer() | nil
        }
  @type custom_consumer :: {module(), args :: any()}
  @type channel_number :: non_neg_integer()

  @doc """
  Opens a new Channel in a previously opened Connection.

  Allows optionally to pass a `t:custom_consumer/0` to start a custom consumer
  implementation. The consumer must implement the `:amqp_gen_consumer` behavior
  from `:amqp_client`. See `:amqp_connection.open_channel/2` for more details
  and `AMQP.DirectConsumer` for an example of a custom consumer.

  Allows for a channel number to be passed as a third argument. See `:amqp_connection.open_channel/3`
  """
  @spec open(Connection.t(), custom_consumer() | nil, channel_number() | nil) ::
          {:ok, Channel.t()} | {:error, any}
  def open(conn, custom_consumer \\ {SelectiveConsumer, self()}, channel_number \\ nil)

  def open(%Connection{} = conn, {_, _} = custom_consumer, channel_number)
      when is_nil(channel_number) do
    do_open_channel(conn, custom_consumer)
  end

  def open(%Connection{} = conn, nil, nil) do
    do_open_channel(conn, nil)
  end

  def open(%Connection{} = conn, custom_consumer, nil) do
    do_open_channel(conn, custom_consumer)
  end

  def open(%Connection{} = conn, custom_consumer, channel_number)
      when is_number(channel_number) do
    do_open_channel(conn, custom_consumer, channel_number)
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

  defp do_open_channel(conn, nil, channel_number) do
    case :amqp_connection.open_channel(conn.pid, channel_number) do
      {:ok, chan_pid} ->
        {:ok, %Channel{conn: conn, pid: chan_pid, channel_number: channel_number}}

      error ->
        {:error, error}
    end
  end

  defp do_open_channel(conn, custom_consumer, channel_number) do
    case :amqp_connection.open_channel(conn.pid, channel_number, custom_consumer) do
      {:ok, chan_pid} ->
        {:ok,
         %Channel{
           conn: conn,
           pid: chan_pid,
           custom_consumer: custom_consumer,
           channel_number: channel_number
         }}

      error ->
        {:error, error}
    end
  end
end
