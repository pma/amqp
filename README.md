# AMQP

[![Build Status](https://travis-ci.org/pma/amqp.png?branch=master)](https://travis-ci.org/pma/amqp)
[![Hex Version](http://img.shields.io/hexpm/v/amqp.svg)](https://hex.pm/packages/amqp)
[![Inline docs](http://inch-ci.org/github/pma/amqp.svg?branch=master)](http://inch-ci.org/github/pma/amqp)

Simple Elixir wrapper for the Erlang RabbitMQ client.

The API is based on Langohr, a Clojure client for RabbitMQ.

Disclaimer: This wrapper library is built on top of a modified version of the Erlang RabbitMQ client, since currently the officially supported Erlang client is not rebar-friendly and is not available on Hex package manager.

## Usage

Add AMQP as a dependency in your `mix.exs` file.

```elixir
def deps do
  [{:amqp, "0.1.5"}]
end
```

You should also update your application list to include `:amqp`:

```elixir
def application do
  [applications: [:amqp]]
end
```

After you are done, run `mix deps.get` in your shell to fetch and compile AMQP. Start an interactive Elixir shell with `iex -S mix`.

```iex
iex> {:ok, conn} = AMQP.Connection.open
{:ok, %AMQP.Connection{pid: #PID<0.165.0>}}
iex> {:ok, chan} = AMQP.Channel.open(conn)
{:ok, %AMQP.Channel{conn: %AMQP.Connection{pid: #PID<0.165.0>}, pid: #PID<0.177.0>}
iex> AMQP.Queue.declare chan, "test_queue"
{:ok, %{consumer_count: 0, message_count: 0, queue: "test_queue"}}
iex> AMQP.Exchange.declare chan, "test_exchange"
:ok
iex> AMQP.Queue.bind chan, "test_queue", "test_exchange"
:ok
iex> AMQP.Basic.publish chan, "test_exchange", "", "Hello, World!"
:ok
iex> {:ok, payload, meta} = AMQP.Basic.get chan, "test_queue"
iex> payload
"Hello, World!"
iex> AMQP.Queue.subscribe chan, "test_queue", fn(payload, _meta) -> IO.puts("Received: #{payload}") end
{:ok, "amq.ctag-5L8U-n0HU5doEsNTQpaXWg"}
iex> AMQP.Basic.publish chan, "test_exchange", "", "Hello, World!"
:ok
Received: Hello, World!
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
    # Limit unacknowledged messages to 10
    Basic.qos(chan, prefetch_count: 10)
    Queue.declare(chan, @queue_error, durable: true)
    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    Queue.declare(chan, @queue, durable: true,
                                arguments: [{"x-dead-letter-exchange", :longstr, ""},
                                            {"x-dead-letter-routing-key", :longstr, @queue_error}])
    Exchange.fanout(chan, @exchange, durable: true)
    Queue.bind(chan, @queue, @exchange)
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
    spawn fn -> consume(chan, tag, redelivered, payload) end
    {:noreply, chan}
  end

  defp consume(channel, tag, redelivered, payload) do
    try do
      number = String.to_integer(payload)
      if number <= 10 do
        Basic.ack channel, tag
        IO.puts "Consumed a #{number}."
      else
        Basic.reject channel, tag, requeue: false
        IO.puts "#{number} is too big and was rejected."
      end
    rescue
      exception ->
        # Requeue unless it's a redelivered message.
        # This means we will retry consuming a message once in case of exception
        # before we give up and have it moved to the error queue
        Basic.reject channel, tag, requeue: not redelivered
        IO.puts "Error converting #{payload} to integer"
    end
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

## Stable RabbitMQ Connection

While the above example works, it does nothing to handle RabbitMQ connection
outages. In case of an outage your Genserver will remain stale and won't
receive any messages from the broker as the connection is never restarted.

Luckily, implementing a reconnection logic is quite straight forward. Since the
connection record holds the pid of the connection itself, we can monitor it
and get a notification when it goes down.

Example implementation (only changes from the last example):
```elixir
# 1. Extract your connect logic into a private method rabbitmq_connect

def init(_opts) do
  rabbitmq_connect
end

defp rabbitmq_connect
    case Connection.open("amqp://guest:guest@localhost") do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        Process.monitor(conn.pid)
        # Everything else remains the same
        {:ok, chan} = Channel.open(conn)
        Basic.qos(chan, prefetch_count: 10)
        Queue.declare(chan, @queue_error, durable: true)
        Queue.declare(chan, @queue, durable: true,
                                    arguments: [{"x-dead-letter-exchange", :longstr, ""},
                                                {"x-dead-letter-routing-key", :longstr, @queue_error}])
        Exchange.fanout(chan, @exchange, durable: true)
        Queue.bind(chan, @queue, @exchange)
        {:ok, _consumer_tag} = Basic.consume(chan, @queue)
        {:ok, chan}
      {:error, _} ->
        # Reconnection loop
        :timer.sleep(10000)
        rabbitmq_connect
    end
end

# 2. Implement a callback to handle DOWN notifications from the system
#    This callback should try to reconnect to the server

def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
  {:ok, chan} = rabbitmq_connect
  {:noreply, chan}
end
```

Now, when the connection drops, or if the server is down when your application
starts, it will try to reconnect indefinitely until it succeeds. 
## Types of arguments and headers

The parameter `arguments` in `Queue.declare`, `Exchange.declare`, `Basic.consume` and the parameter `headers` in `Basic.publish` are a list of tuples in the form `{name, type, value}`, where `name` is a binary containing the argument/header name, `type` is an atom describing the AMQP field type and `value` a term compatible with the AMQP field type.

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


## Upgrading from 0.0.6 to 0.1.0

Version 0.1.0 includes the following breaking changes:

  * Basic.consume now takes the consumer process pid as the third argument. This is optional
  and defaults to the caller.
  * When registering a consumer process with Basic.consume, this process will receive the
  messages consumed from the Queue as the tuple `{:basic_deliver, payload, meta}` instead of
  the previous format `{payload, meta}`.
  * A consumer process registered with Basic.consume will have to handle (or ignore) the
  following additional messages: `{:basic_consume_ok, %{consumer_tag: consumer_tag}}`, `{:basic_cancel, %{consumer_tag: consumer_tag}}`
  and `{:basic_cancel_ok, %{consumer_tag: consumer_tag}}`.
