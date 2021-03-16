# AMQP

[![Build Status](https://github.com/pma/amqp/workflows/Elixir%20CI/badge.svg?branch=main)](https://github.com/pma/amqp/actions?query=workflow%3A%22Elixir+CI%22+branch%3Amain)
[![Module Version](https://img.shields.io/hexpm/v/amqp.svg)](https://hex.pm/packages/amqp)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/amqp/)
[![Total Download](https://img.shields.io/hexpm/dt/amqp.svg)](https://hex.pm/packages/amqp)
[![Last Updated](https://img.shields.io/github/last-commit/pma/amqp.svg)](https://github.com/pma/amqp/commits/main)
[![License](https://img.shields.io/hexpm/l/amqp.svg)](https://github.com/pma/amqp/blob/main/LICENSE)

Simple Elixir wrapper for the Erlang RabbitMQ client.

The API is based on Langohr, a Clojure client for RabbitMQ.

## Upgrading guides

To upgrade from the old version, please read our upgrade guides:

* [0.x to 1.x](https://github.com/pma/amqp/wiki/Upgrade-from-0.X-to-1.0)
* [1.x to 2.x](https://github.com/pma/amqp/wiki/2.0-Release-Notes#breaking-changes-and-upgrade-guide)

## Usage

Add AMQP as a dependency in your `mix.exs` file.

```elixir
def deps do
  [
    {:amqp, "~> 2.1"}
  ]
end
```

Elixir will start `amqp` automatically with this if you use Elixir 1.6+.

If that's not the case (use `Application.started_applications/0` to check), try
adding `:amqp` to `applications` or `extra_applications` in your `mix.exs`. Or
call `Application.ensure_started(:amqp)` at the start.

After you are done, run `mix deps.get` in your shell to fetch and compile AMQP.
Start an interactive Elixir shell with `iex -S mix`.

```elixir
iex> {:ok, conn} = AMQP.Connection.open()
# {:ok, %AMQP.Connection{pid: #PID<0.165.0>}}

iex> {:ok, chan} = AMQP.Channel.open(conn)
# {:ok, %AMQP.Channel{conn: %AMQP.Connection{pid: #PID<0.165.0>}, pid: #PID<0.177.0>}

iex> AMQP.Queue.declare(chan, "test_queue")
# {:ok, %{consumer_count: 0, message_count: 0, queue: "test_queue"}}

iex> AMQP.Exchange.declare(chan, "test_exchange")
# :ok

iex> AMQP.Queue.bind(chan, "test_queue", "test_exchange")
# :ok

iex> AMQP.Basic.publish(chan, "test_exchange", "", "Hello, World!")
# :ok

iex> {:ok, payload, meta} = AMQP.Basic.get(chan, "test_queue")
iex> payload
# "Hello, World!"

iex> AMQP.Queue.subscribe(chan, "test_queue", fn payload, _meta -> IO.puts("Received: #{payload}") end)
# {:ok, "amq.ctag-5L8U-n0HU5doEsNTQpaXWg"}

iex> AMQP.Basic.publish(chan, "test_exchange", "", "Hello, World!")
# :ok
# Received: Hello, World!
```

### Setup a consumer GenServer

```elixir
defmodule Consumer do
  use GenServer
  use AMQP

  def start_link do
    GenServer.start_link(__MODULE__, [], [])
  end

  @exchange    "gen_server_test_exchange"
  @queue       "gen_server_test_queue"
  @queue_error "#{@queue}_error"

  def init(_opts) do
    {:ok, conn} = Connection.open("amqp://guest:guest@localhost")
    {:ok, chan} = Channel.open(conn)
    setup_queue(chan)

    # Limit unacknowledged messages to 10
    :ok = Basic.qos(chan, prefetch_count: 10)
    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = Basic.consume(chan, @queue)
    {:ok, chan}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, chan) do
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, chan) do
    {:stop, :normal, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, chan) do
    # You might want to run payload consumption in separate Tasks in production
    consume(chan, tag, redelivered, payload)
    {:noreply, chan}
  end

  defp setup_queue(chan) do
    {:ok, _} = Queue.declare(chan, @queue_error, durable: true)
    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    {:ok, _} = Queue.declare(chan, @queue,
                             durable: true,
                             arguments: [
                               {"x-dead-letter-exchange", :longstr, ""},
                               {"x-dead-letter-routing-key", :longstr, @queue_error}
                             ]
                            )
    :ok = Exchange.fanout(chan, @exchange, durable: true)
    :ok = Queue.bind(chan, @queue, @exchange)
  end

  defp consume(channel, tag, redelivered, payload) do
    number = String.to_integer(payload)
    if number <= 10 do
      :ok = Basic.ack channel, tag
      IO.puts "Consumed a #{number}."
    else
      :ok = Basic.reject channel, tag, requeue: false
      IO.puts "#{number} is too big and was rejected."
    end

  rescue
    # Requeue unless it's a redelivered message.
    # This means we will retry consuming a message once in case of exception
    # before we give up and have it moved to the error queue
    #
    # You might also want to catch :exit signal in production code.
    # Make sure you call ack, nack or reject otherwise comsumer will stop
    # receiving messages.
    exception ->
      :ok = Basic.reject channel, tag, requeue: not redelivered
      IO.puts "Error converting #{payload} to integer"
  end
end
```

```iex
iex> Consumer.start_link
{:ok, #PID<0.261.0>}
iex> {:ok, conn} = AMQP.Connection.open
{:ok, %AMQP.Connection{pid: #PID<0.165.0>}}
iex> {:ok, chan} = AMQP.Channel.open(conn)
{:ok, %AMQP.Channel{conn: %AMQP.Connection{pid: #PID<0.165.0>}, pid: #PID<0.177.0>}
iex> AMQP.Basic.publish chan, "gen_server_test_exchange", "", "5"
:ok
Consumed a 5.
iex> AMQP.Basic.publish chan, "gen_server_test_exchange", "", "42"
:ok
42 is too big and was rejected.
iex> AMQP.Basic.publish chan, "gen_server_test_exchange", "", "Hello, World!"
:ok
Error converting Hello, World! to integer
Error converting Hello, World! to integer
```

### Configuration

#### Erlang library's progress report

This library uses an official Erlang RabbitMQ client library internally and we
found its logging is too verbose.

These are called progress reports by the Erlang library and you would see a lot
of entries with info log level if you use 1.x version.

AMQP disables that by default from version 2.0. If you want to see more
detailed logs, you can enable it by adding the following line on your config.

```elixir
config :amqp, enable_progress_report: true
```

#### Connections and channels

You can define a connection and channel in your config and AMQP will
automatically...

* Open the connection and channel at the start of the application
* Automatically try to reconnect if they are disconnected

```elixir
config :amqp,
  connections: [
    myconn: [url: "amqp://guest:guest@myhost:12345"],
  ],
  channels: [
    mychan: [connection: :myconn]
  ]
```

You can access the connection/channel via `AMQP.Application`.

```elixir
iex> {:ok, chan} = AMQP.Application.get_channel(:mychan)
iex> :ok = AMQP.Basic.publish(chan, "", "", "Hello")
```

When a channel is down and reconnected, you have to make sure your consumer
subscribes to a channel again.

See the documentation for `AMQP.Application.get_connection/1` and
`AMQP.Application.get_channel/1` for more details.

### Types of arguments and headers

The parameter `arguments` in `Queue.declare`, `Exchange.declare`,
`Basic.consume` and the parameter `headers` in `Basic.publish` are a list of
tuples in the form `{name, type, value}`, where `name` is a binary containing
the argument/header name, `type` is an atom describing the AMQP field type and
`value` a term compatible with the AMQP field type.

The valid AMQP field types are:

`:longstr` | `:signedint` | `:decimal` | `:timestamp` | `:table` | `:byte` | `:double` | `:float` | `:long` | `:short` | `:bool` | `:binary` | `:void` | `:array`

Valid argument names in `Queue.declare` include:

* "x-expires"
* "x-message-ttl"
* "x-dead-letter-routing-key"
* "x-dead-letter-exchange"
* "x-max-length"
* "x-max-length-bytes"

Valid argument names in `Basic.consume` include:

* "x-priority"
* "x-cancel-on-ha-failover"

Valid argument names in `Exchange.declare` include:

* "alternate-exchange"

## Troubleshooting / FAQ

#### Consumer stops receiving messages

It usually happens when your code doesn't send acknowledgement(ack, nack or
reject) after receiving a message.

If you use GenServer for your consumer, try storing the number of messages the
server is currently processing to the GenServer state.

If the number equals `prefetch_count`, those messages were left without
acknowledgements and that's why the consumer has stopped receiving more
messages.

Also review the following points:

- when an exception was raised how it would be handled
- when :exit signal was thrown how it would be handled
- when a message processing took long time what could happen

Also make sure that the consumer monitors the channel pid. When the channel is
gone, you have to reopen it and subscribe to a new channel again.

#### The version compatibility

Check out [this article](https://github.com/pma/amqp/wiki/Versions-and-Compatibilities) to find out the compatibility with Elixir, OTP and RabbitMQ.

#### Heartbeats

In case the connection is dropped automatically, consider enabling heartbeats.

You can set `heartbeat` option when you open a connection.

For more details, read [this article](http://www.rabbitmq.com/heartbeats.html#tcp-proxies)

#### Log related to amqp supervisors are too verbose

Try the following configuration.

```elixir
config :logger, handle_otp_reports: false
```

#### Lager conflicts with Elixir logger

Lager is used by rabbit_common and it is not Elixir's best friend yet.
You need a workaround.

In mix.exs, you have to load :lager before :logger.

```elixir
  extra_applications: [:lager, :logger, :amqp]
```

Here is a sample configuration to silent rabbit_common logging.

```elixir
config :lager,
  error_logger_redirect: false,
  handlers: [level: :critical]
```

Check out
[Lager](https://github.com/erlang-lager/lager#configuration) and [RabbitMQ
documentation](https://www.rabbitmq.com/logging.html#advanced-configuration) for
more information.

#### Compile error on ranch_proxy_protocol with OTP 21

Update amqp to [1.1.0](https://github.com/pma/amqp/releases/tag/v1.1.0) or a greater version.

#### Does the library support AMQP 1.0?

Currently the library doesn't support AMQP 1.0 and there is no plan to do so at
the moment. Our main aim here (at least for now) is to provide a thin wrapper
around [amqp_client](https://hex.pm/packages/amqp_client) for Elixir
programmers.


## Copyright and License

Copyright (c) 2014 Paulo Almeida

This library is MIT licensed. See the
[LICENSE](https://github.com/pma/amqp/blob/main/LICENSE) for details.
