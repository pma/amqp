defmodule TransactionTest do
  use ExUnit.Case

  alias AMQP.{Basic, Channel, Connection, Queue, Transaction}

  setup do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    {:ok, observer} = Channel.open(conn)
    {:ok, %{queue: queue}} = Queue.declare(observer, "", exclusive: true)
    on_exit(fn -> Connection.close(conn) end)
    :ok = Transaction.select(chan)
    {:ok, chan: chan, observer: observer, queue: queue}
  end

  test "commit makes pending publishes visible and supports subsequent transactions", ctx do
    assert :ok = Basic.publish(ctx.chan, "", ctx.queue, "committed")
    assert {:empty, _} = Basic.get(ctx.observer, ctx.queue)
    assert :ok = Transaction.commit(ctx.chan)
    assert {:ok, "committed", _} = Basic.get(ctx.observer, ctx.queue, no_ack: true)

    assert :ok = Basic.publish(ctx.chan, "", ctx.queue, "next transaction")
    assert :ok = Transaction.commit(ctx.chan)
    assert {:ok, "next transaction", _} = Basic.get(ctx.observer, ctx.queue, no_ack: true)
  end

  test "rollback discards pending publishes and leaves the channel in transaction mode", ctx do
    assert :ok = Basic.publish(ctx.chan, "", ctx.queue, "rolled back")
    assert :ok = Transaction.rollback(ctx.chan)
    assert :ok = Transaction.commit(ctx.chan)
    assert {:empty, _} = Basic.get(ctx.observer, ctx.queue)

    assert :ok = Basic.publish(ctx.chan, "", ctx.queue, "after rollback")
    assert :ok = Transaction.commit(ctx.chan)
    assert {:ok, "after rollback", _} = Basic.get(ctx.observer, ctx.queue, no_ack: true)
  end

  test "commit applies acknowledgements", ctx do
    :ok = AMQP.Confirm.select(ctx.observer)
    :ok = Basic.publish(ctx.observer, "", ctx.queue, "acknowledged")
    assert true == AMQP.Confirm.wait_for_confirms(ctx.observer, {5_000, :millisecond})
    {:ok, "acknowledged", %{delivery_tag: tag}} = Basic.get(ctx.chan, ctx.queue)
    assert :ok = Basic.ack(ctx.chan, tag)
    assert :ok = Transaction.commit(ctx.chan)
    assert :ok = Channel.close(ctx.chan)
    assert {:empty, _} = Basic.get(ctx.observer, ctx.queue)
  end
end
