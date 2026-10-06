defmodule QueueTest do
  use ExUnit.Case

  alias AMQP.Connection
  alias AMQP.Channel
  alias AMQP.Exchange
  alias AMQP.Queue

  setup do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    on_exit(fn -> :ok = Connection.close(conn) end)
    {:ok, conn: conn, chan: chan}
  end

  test "declare queue with server assigned name", meta do
    assert {:ok, %{queue: queue, message_count: 0, consumer_count: 0}} =
             Queue.declare(meta[:chan])

    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue)
  end

  test "purge without options preserves the message count result", meta do
    {:ok, %{queue: queue}} = Queue.declare(meta[:chan], "", exclusive: true)
    :ok = AMQP.Basic.publish(meta[:chan], "", queue, "discard")
    assert {:ok, %{message_count: 1}} = Queue.purge(meta[:chan], queue)
    assert {:empty, _} = AMQP.Basic.get(meta[:chan], queue)
  end

  for option <- [:nowait, :no_wait] do
    test "purge with #{option} discards messages", meta do
      {:ok, %{queue: queue}} = Queue.declare(meta[:chan], "", exclusive: true)
      :ok = AMQP.Basic.publish(meta[:chan], "", queue, "discard")
      assert :ok = Queue.purge(meta[:chan], queue, [{unquote(option), true}])
      assert {:empty, _} = AMQP.Basic.get(meta[:chan], queue)
    end
  end

  test "declare queue with nowait option", meta do
    assert :ok = Queue.declare(meta[:chan], "hello", nowait: true)
    assert :ok = Queue.delete(meta[:chan], "hello", nowait: true)
  end

  test "declare queue with explicitly assigned name", meta do
    name = rand_name()

    assert {:ok, %{queue: ^name, message_count: 0, consumer_count: 0}} =
             Queue.declare(meta[:chan], name)

    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], name)
  end

  test "bind and unbind queue to exchange", meta do
    queue = rand_name()
    exchange = rand_name()
    assert :ok = Exchange.fanout(meta[:chan], exchange)

    assert {:ok, %{queue: ^queue, message_count: 0, consumer_count: 0}} =
             Queue.declare(meta[:chan], queue)

    assert :ok = Queue.bind(meta[:chan], queue, exchange)
    assert :ok = Queue.unbind(meta[:chan], queue, exchange)
    assert :ok = Exchange.delete(meta[:chan], exchange)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue)
  end

  test "bind with nowait option", meta do
    queue = rand_name()
    exchange = rand_name()
    assert :ok = Exchange.fanout(meta[:chan], exchange)

    assert {:ok, %{queue: ^queue, message_count: 0, consumer_count: 0}} =
             Queue.declare(meta[:chan], queue)

    assert :ok = Queue.bind(meta[:chan], queue, exchange, nowait: true)
    assert :ok = Queue.unbind(meta[:chan], queue, exchange)
    assert :ok = Exchange.delete(meta[:chan], exchange)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue)
  end

  test "status returns message count and consumer count", meta do
    queue = rand_name()

    assert {:ok, %{queue: ^queue, message_count: 0, consumer_count: 0}} =
             Queue.declare(meta[:chan], queue)

    assert {:ok, %{message_count: 0, consumer_count: 0}} = Queue.status(meta[:chan], queue)
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue)
  end

  test "message_count returns number of messages in queue", meta do
    queue = rand_name()

    assert {:ok, %{queue: ^queue, message_count: 0, consumer_count: 0}} =
             Queue.declare(meta[:chan], queue)

    assert Queue.message_count(meta[:chan], queue) == 0
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue)
  end

  test "consumer_count returns number of consumers in queue", meta do
    queue = rand_name()

    assert {:ok, %{queue: ^queue, message_count: 0, consumer_count: 0}} =
             Queue.declare(meta[:chan], queue)

    assert Queue.consumer_count(meta[:chan], queue) == 0
    assert {:ok, %{message_count: 0}} = Queue.delete(meta[:chan], queue)
  end

  defp rand_name do
    :crypto.strong_rand_bytes(8) |> Base.encode64()
  end
end
