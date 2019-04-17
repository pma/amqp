# AMQP

[![Build Status](https://travis-ci.org/pma/amqp.png?branch=master)](https://travis-ci.org/pma/amqp)
[![Hex Version](http://img.shields.io/hexpm/v/amqp.svg)](https://hex.pm/packages/amqp)
[![Inline docs](http://inch-ci.org/github/pma/amqp.svg?branch=master)](http://inch-ci.org/github/pma/amqp)

Simple Elixir wrapper for the Erlang RabbitMQ client.

The API is based on Langohr, a Clojure client for RabbitMQ.

## Migration from 0.X to 1.X

If you use amqp 0.X and plan to migrate to 1.0 please read our [migration guide](https://github.com/pma/amqp/wiki/Upgrade-from-0.X-to-1.0).

## Usage

Add AMQP as a dependency in your `mix.exs` file.

```elixir
def deps do
  [{:amqp, "~> 1.1"}]
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

## Stable RabbitMQ Connection

While the above example works, it does nothing to handle RabbitMQ connection
outages. In case of an outage your Genserver will remain stale and won't
receive any messages from the broker as the connection is never restarted.

Luckily, implementing a reconnection logic is quite straight forward. Since the
connection record holds the pid of the connection itself, we can monitor it
and get a notification when it goes down.

Example implementation:

```elixir
defmodule MyApp.AMQP do
  use GenServer
  require Logger
  alias AMQP.Connection

  @host "amqp://localhost"
  @reconnect_interval 10_000

  def start_link(opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(_) do
    send(self(), :connect)
    {:ok, nil}
  end

  def get_connection do
    case GenServer.call(__MODULE__, :get) do
      nil -> {:error, :not_connected}
      conn -> {:ok, conn}
    end
  end

  def handle_call(:get, _, conn) do
    {:reply, conn, conn}
  end

  def handle_info(:connect, conn) do
    case Connection.open(@host) do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        Process.monitor(conn.pid)
        {:noreply, conn}

      {:error, _} ->
        Logger.error("Failed to connect #{@host}. Reconnecting later...")
        # Retry later
        Process.send_after(self(), :connect, @reconnect_interval)
        {:noreply, nil}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _) do
    # Stop GenServer. Will be restarted by Supervisor.
    {:stop, {:connection_lost, reason}, nil}
  end
end
```

Now, when the server starts, it will try to reconnect indefinitely until it succeeds.
When the connection drops or the server is down, the GenServer will stop.
If you have put the GenServer module to your application tree, the Supervisor will automatically restart it.
Then it will try to reconnect indefinitely until it succeeds.

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

## Troubleshooting / FAQ

#### Connections and Channels

If this is your first time using RabbitMQ, we recommend you to start designing your application like this way:

- Open and manage a single connection for an application
- Open/close a channel per process (don't share a channel between multiple processes)

Then you can consider optimising the performance by increasing number of connections etc.

Note it's completely safe to share a single connection between multiple processes.
However it is not recommended to share a channel between multiple processes.
It's technically possible but you want to understand the implications when you do.

Make sure you close the channel after used to avoid any potential memory leaks and warnings from RabbitMQ client library.

#### Consumer stops receiving messages

Most popular cause is your code not sending acknowledgement(ack, nack or reject)
after receiving a message.
You want to investigate if...

- an exception was raised and how it would be handled
- :exit signal was thrown and how it would be handled
- a message processing took long time.

If you use GenServer in consumer, try storing number of messages the server is
currently processing to the GenServer state.
If the number equals `prefetch\_count`, those messages were left without
acknowledgements and that's why consumer have stopped receiving more
messages.

#### Old version of Elixir or OTP

OTP 17 and 18 are supported only on [version 0.1.x](https://github.com/pma/amqp/tree/v0.1).
Please understand that we won't make further changes to 0.1 except for major security issues.

#### Heartbeats

In case the connection is dropped automatically, consider enabling heartbeats.
You can set `heartbeat` option when you open a connection.

For more details, read [this article](http://www.rabbitmq.com/heartbeats.html#tcp-proxies)

#### Log related to amqp supervisors are too verbose

Try the following configuration.

```elixir
config :logger, handle_otp_reports: false
```

Or try filtering out the messages at your application start:

```elixir
:logger.add_primary_filter(
  :ignore_rabbitmq_progress_reports,
  {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
)
```

See [this comment](https://github.com/pma/amqp/issues/110#issuecomment-442761299) for the
details.

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

Currently the library doesn't support AMQP 1.0 and there is no plan to do so at the moment. Our main aim here (at least for now) is to provide a thin wrapper around [amqp_client](https://hex.pm/packages/amqp_client) for Elixir programmers.
