defmodule AMQP.Exchange do
  @moduledoc """
  Functions to operate on Exchanges.
  """

  import AMQP.Core

  alias AMQP.{Basic, Channel}

  @doc """
  Declares an Exchange. The default Exchange type is `direct`.

  AMQP 0-9-1 brokers provide four pre-declared exchanges:

    * `:direct` exchange: (empty string) or `amq.direct`

    * `:fanout` exchange: `amq.fanout`

    * `:topic` exchange: `amq.topic`

    * `:headers` exchange: `amq.match` (and `amq.headers` in RabbitMQ)

  Besides the exchange name and type, the following options can be used:

  ## Options

    * `:durable` - If set, keeps the Exchange between restarts of the broker

    * `:auto_delete` - If set, deletes the Exchange once all queues unbind from
      it

    * `:passive` - If set, returns an error if the Exchange does not already
      exist

    * `:internal` - If set, the exchange may not be used directly by
      publishers, but only when bound to other exchanges. Internal exchanges are
      used to construct wiring that is not visible to applications

    * `:nowait` - If set, the declare operation is asynchronous (default `false`)

    * `:arguments` - A list of arguments to pass when declaring (of type
      `t:AMQP.arguments/0`).  See the [README](readme.html) for more information
      (default to `[]`)

  """
  @spec declare(Channel.t(), Basic.exchange(), type :: atom, keyword) :: :ok | Basic.error()
  def declare(%Channel{pid: pid}, exchange, type \\ :direct, options \\ []) do
    nowait = get_nowait(options)

    exchange_declare =
      exchange_declare(
        exchange: exchange,
        type: Atom.to_string(type),
        passive: Keyword.get(options, :passive, false),
        durable: Keyword.get(options, :durable, false),
        auto_delete: Keyword.get(options, :auto_delete, false),
        internal: Keyword.get(options, :internal, false),
        nowait: nowait,
        arguments: Keyword.get(options, :arguments, [])
      )

    case {nowait, :amqp_channel.call(pid, exchange_declare)} do
      {true, :ok} -> :ok
      {_, exchange_declare_ok()} -> :ok
      {_, error} -> {:error, error}
    end
  end

  @doc """
  Deletes an Exchange by name. When an Exchange is deleted all bindings to it are
  also deleted.

  ## Options

    * `:if_unused` - If set, the server will only delete the exchange if it has
      no queue bindings

    * `:nowait` - If set, the delete operation is asynchronous (default
      `false`)

  """
  @spec delete(Channel.t(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def delete(%Channel{pid: pid}, exchange, options \\ []) do
    nowait = get_nowait(options)

    exchange_delete =
      exchange_delete(
        exchange: exchange,
        if_unused: Keyword.get(options, :if_unused, false),
        nowait: nowait
      )

    case {nowait, :amqp_channel.call(pid, exchange_delete)} do
      {true, :ok} -> :ok
      {_, exchange_delete_ok()} -> :ok
      {_, error} -> {:error, error}
    end
  end

  @doc """
  Binds an Exchange to another Exchange using the exchange.bind AMQP method (a
  RabbitMQ-specific extension).

  ## Options

    * `:routing_key` - the routing key to use for the binding (default `""`)

    * `:nowait` - If set, the bind operation is asynchronous (default `false`)

    * `:arguments` - A list of arguments to pass when binding (of type
      `t:AMQP.arguments/0`). See the [README](readme.html) for more information
      (default to `[]`)

  """
  @spec bind(Channel.t(), destination :: String.t(), source :: String.t(), keyword) ::
          :ok | Basic.error()
  def bind(%Channel{pid: pid}, destination, source, options \\ []) do
    nowait = get_nowait(options)

    exchange_bind =
      exchange_bind(
        destination: destination,
        source: source,
        routing_key: Keyword.get(options, :routing_key, ""),
        nowait: nowait,
        arguments: Keyword.get(options, :arguments, [])
      )

    case {nowait, :amqp_channel.call(pid, exchange_bind)} do
      {true, :ok} -> :ok
      {_, exchange_bind_ok()} -> :ok
      {_, error} -> {:error, error}
    end
  end

  @doc """
  Unbinds an Exchange from another Exchange or a Queue using the
  exchange.unbind AMQP method (a RabbitMQ-specific extension).

  ## Options

    * `:routing_key` - the routing key to use for the binding (default `""`)

    * `:nowait` - If set, the declare operation is asynchronous (default `false`)

    * `:arguments` - A list of arguments to pass when declaring (of type
      `t:AMQP.arguments/0`). See the README for more information (defaults `[]`)

  """
  @spec unbind(Channel.t(), destination :: String.t(), source :: String.t(), keyword) ::
          :ok | Basic.error()
  def unbind(%Channel{pid: pid}, destination, source, options \\ []) do
    nowait = get_nowait(options)

    exchange_unbind =
      exchange_unbind(
        destination: destination,
        source: source,
        routing_key: Keyword.get(options, :routing_key, ""),
        nowait: nowait,
        arguments: Keyword.get(options, :arguments, [])
      )

    case {nowait, :amqp_channel.call(pid, exchange_unbind)} do
      {true, :ok} -> :ok
      {_, exchange_unbind_ok()} -> :ok
      {_, error} -> {:error, error}
    end
  end

  @doc """
  Convenience function to declare an Exchange of type `direct`.

  ## Options

  This function takes the same options as `declare/4`.
  """
  @spec direct(Channel.t(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def direct(%Channel{} = channel, exchange, options \\ []) do
    declare(channel, exchange, :direct, options)
  end

  @doc """
  Convenience function to declare an Exchange of type `fanout`.

  ## Options

  This function takes the same options as `declare/4`.
  """
  @spec fanout(Channel.t(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def fanout(%Channel{} = channel, exchange, options \\ []) do
    declare(channel, exchange, :fanout, options)
  end

  @doc """
  Convenience function to declare an Exchange of type `topic`.

  ## Options

  This function takes the same options as `declare/4`.
  """
  @spec topic(Channel.t(), Basic.exchange(), keyword) :: :ok | Basic.error()
  def topic(%Channel{} = channel, exchange, options \\ []) do
    declare(channel, exchange, :topic, options)
  end

  # support backward compatibility with old key name
  defp get_nowait(opts) do
    Keyword.get(opts, :nowait, false) || Keyword.get(opts, :no_wait, false)
  end
end
