defmodule AMQP.Channel.ReceiverTest do
  use ExUnit.Case

  alias AMQP.{Basic, Connection, Channel, Queue}
  alias Channel.ReceiverManager

  setup do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    {:ok, %{queue: queue}} = Queue.declare(chan)

    on_exit(fn ->
      Queue.delete(chan, queue)
      :ok = Channel.close(chan)
      :ok = Connection.close(conn)
    end)

    {:ok, conn: conn, chan: chan, queue: queue}
  end

  test "closes the receiver when channel is closed", meta do
    {:ok, chan} = Channel.open(meta.conn)

    {:ok, consumer_tag} = Basic.consume(chan, meta.queue)
    assert_receive {:basic_consume_ok, %{consumer_tag: ^consumer_tag}}

    receiver = ReceiverManager.get_receiver(chan.pid, self())
    assert Process.alive?(receiver.pid)

    :ok = Channel.close(chan)
    :timer.sleep(100)
    refute ReceiverManager.get_receiver(chan.pid, self())
    refute Process.alive?(receiver.pid)
  end

  test "closes the receiver when the client is closed", meta do
    {:ok, chan} = Channel.open(meta.conn)

    task =
      Task.async(fn ->
        {:ok, consumer_tag} = Basic.consume(chan, meta.queue)
        assert_receive {:basic_consume_ok, %{consumer_tag: ^consumer_tag}}
        ReceiverManager.get_receiver(chan.pid, self())
      end)

    receiver = Task.await(task)
    :timer.sleep(100)
    refute Process.alive?(task.pid)
    refute Process.alive?(receiver.pid)
    refute ReceiverManager.get_receiver(chan.pid, task.pid)

    :ok = Channel.close(chan)
  end

  test "closes the receiver when all handlers are cancelled", meta do
    {:ok, chan} = Channel.open(meta.conn)

    {:ok, consumer_tag} = Basic.consume(chan, meta.queue)
    assert_receive {:basic_consume_ok, %{consumer_tag: ^consumer_tag}}

    receiver = ReceiverManager.get_receiver(chan.pid, self())
    assert Process.alive?(receiver.pid)

    {:ok, ^consumer_tag} = Basic.cancel(chan, consumer_tag)
    :timer.sleep(100)
    refute ReceiverManager.get_receiver(chan.pid, self())
    refute Process.alive?(receiver.pid)

    :ok = Channel.close(chan)
  end

  test "unregisters the receiver when the register process dies", meta do
    {:ok, chan} = Channel.open(meta.conn)

    {:ok, consumer_tag} = Basic.consume(chan, meta.queue)
    assert_receive {:basic_consume_ok, %{consumer_tag: ^consumer_tag}}

    receiver = ReceiverManager.get_receiver(chan.pid, self())
    assert Process.alive?(receiver.pid)

    Process.exit(receiver.pid, :normal)
    :timer.sleep(100)
    refute ReceiverManager.get_receiver(chan.pid, self())

    :ok = Channel.close(chan)
  end
end
