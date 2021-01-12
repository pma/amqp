defmodule AMQP.SelectiveConsumerTest do
  use ExUnit.Case

  import AMQP.Core
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
    default_consumer = spawn(&InspectConsumer.message_loop/0)
    SelectiveConsumer.register_default_consumer(chan, default_consumer)

    on_exit(fn ->
      if Process.alive?(chan.pid) do
        Queue.delete(chan, queue)
        send(default_consumer, :stop)
        Channel.close(chan)
      end

      :ok = Connection.close(conn)
    end)

    {:ok, conn: conn, chan: chan, queue: queue}
  end

  describe "with nowait option" do
    test "Basic.consume", meta do
      consumer_tag = "hello"
      opts = [nowait: true, consumer_tag: consumer_tag]
      {:ok, ^consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self(), opts)
      refute_receive {:basic_consume_ok, _}

      Basic.publish(meta[:chan], "", meta[:queue], "hi")
      assert_receive {:basic_deliver, "hi", %{consumer_tag: ^consumer_tag}}

      {:ok, ^consumer_tag} = Basic.cancel(meta[:chan], consumer_tag)
    end

    test "Basic.cancel", meta do
      {:ok, consumer_tag} = Basic.consume(meta[:chan], meta[:queue], self())

      {:ok, ^consumer_tag} = Basic.cancel(meta[:chan], consumer_tag, nowait: true)
      refute_receive {:basic_cancel_ok, _}
    end
  end

  describe "with multiple queues" do
    setup meta do
      {:ok, %{queue: queue2}} = Queue.declare(meta[:chan])

      on_exit(fn ->
        Queue.delete(meta[:chan], queue2)
      end)

      {:ok, queue2: queue2}
    end

    test "does not delete the consumer until all gone", meta do
      {:ok, consumer_tag1} = Basic.consume(meta[:chan], meta[:queue])
      {:ok, consumer_tag2} = Basic.consume(meta[:chan], meta[:queue2])

      {:ok, ^consumer_tag1} = Basic.cancel(meta[:chan], consumer_tag1)

      Basic.publish(meta[:chan], "", meta[:queue2], "hi")
      assert_receive {:basic_deliver, "hi", %{consumer_tag: ^consumer_tag2}}

      Basic.publish(meta[:chan], "", meta[:queue], "hola")
      refute_receive {:basic_deliver, "hola", %{consumer_tag: ^consumer_tag1}}

      {:ok, ^consumer_tag2} = Basic.cancel(meta[:chan], consumer_tag2)
    end
  end

  describe "basic_credit_drained" do
    test "forwards the message to the end consumer", meta do
      {:ok, consumer_tag} = Basic.consume(meta[:chan], meta[:queue])

      # don't know how we can emit the message from the server so use send/2
      # to emulate the message
      msg = basic_credit_drained(consumer_tag: consumer_tag)

      consumer_pid =
        meta[:chan].pid
        |> :sys.get_state()
        |> elem(3)

      send(consumer_pid, msg)
      assert_receive {:basic_credit_drained, %{consumer_tag: ^consumer_tag}}

      {:ok, ^consumer_tag} = Basic.cancel(meta[:chan], consumer_tag)
    end
  end
end
