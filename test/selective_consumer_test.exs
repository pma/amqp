defmodule AMQP.SelectiveConsumerTest do
  use ExUnit.Case

  alias AMQP.{Basic, Connection, Channel, Queue, SelectiveConsumer}

  defmodule InspectConsumer do
    def message_loop do
      receive do
        :stop ->
          :ok

        m ->
          IO.inspect(m)
          message_loop()
      end
    end
  end

  setup do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    {:ok, %{queue: queue}} = Queue.declare(chan)
    defaultc = spawn(&InspectConsumer.message_loop/0)
    SelectiveConsumer.register_default_consumer(chan, defaultc)

    on_exit(fn ->
      :ok = Connection.close(conn)
      if Process.alive?(chan.pid) do
        send(defaultc, :stop)
        Queue.delete(chan, queue)
        Channel.close(chan)
      end
    end)

    {:ok, conn: conn, chan: chan, queue: queue}
  end

  describe "with nowait option" do
    test "Basic.consume", meta do
      consumer_tag = "hello"
      opts = [nowait: true, consumer_tag: consumer_tag]
      {:ok, ^consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self(), opts)
      refute_receive {:basic_consume_ok, _}

      payload = "foo"
      correlation_id = "correlation_id"
      exchange = ""
      routing_key = meta[:queue]

      Basic.publish(meta[:chan], exchange, routing_key, payload, correlation_id: correlation_id)

      assert_receive {:basic_deliver, ^payload,
                      %{
                        consumer_tag: ^consumer_tag,
                        correlation_id: ^correlation_id,
                        routing_key: ^routing_key
                      }}

      {:ok, ^consumer_tag} = Basic.cancel(meta[:chan], consumer_tag)
    end

    test "Basic.cancel and default consumer", meta do
      {:ok, consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self())

      {:ok, ^consumer_tag} = Basic.cancel(meta[:chan], consumer_tag, nowait: true)
      refute_receive {:basic_cancel_ok, _}
    end
  end

  describe "with direct ctx" do

  end

  describe "basic_credit_drained" do

  end

  describe "with multiple queues" do

  end
end
