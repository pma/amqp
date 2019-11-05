defmodule ConfirmTest do
  use ExUnit.Case

  alias AMQP.Connection
  alias AMQP.Channel
  alias AMQP.Confirm

  setup do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    :ok = Confirm.select(chan)

    on_exit(fn ->
      :ok = Connection.close(conn)
    end)

    {:ok, chan: chan}
  end

  describe "next_publish_seqno" do
    test "returns 1 whe no messages where sent", ctx do
      assert 1 == Confirm.next_publish_seqno(ctx[:chan])
    end
  end

  describe "register_handler" do
    test "handler receive confirm with message seqno", ctx do
      :ok = Confirm.register_handler(ctx[:chan], self())
      seq_no = Confirm.next_publish_seqno(ctx[:chan])
      :ok = AMQP.Basic.publish(ctx[:chan], "", "", "foo")

      assert_receive {:basic_ack, ^seq_no, false}
      :ok = Confirm.unregister_handler(ctx[:chan])
    end
  end

  describe "unregister_handler" do
    setup ctx do
      :ok = Confirm.register_handler(ctx[:chan], self())
      {:ok, ctx}
    end

    test "handler no more receive confirm", ctx do
      :ok = Confirm.unregister_handler(ctx[:chan])
      :ok = AMQP.Basic.publish(ctx[:chan], "", "", "foo")
      refute_receive {:basic_ack, 1, false}
    end
  end
end
