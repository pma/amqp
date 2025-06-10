defmodule ChannelTest do
  use ExUnit.Case

  alias AMQP.Connection
  alias AMQP.Channel

  setup do
    {:ok, conn} = Connection.open()
    on_exit(fn -> :ok = Connection.close(conn) end)
    {:ok, conn: conn}
  end

  test "open channel", meta do
    assert {:ok, chan} = Channel.open(meta[:conn])
    assert :ok = Channel.close(chan)
  end

  test "open channel with custom_consumer only", meta do
    assert {:ok, chan} = Channel.open(meta[:conn], {AMQP.DirectConsumer, self()})
    assert {AMQP.DirectConsumer, _pid} = chan.custom_consumer
    assert :ok = Channel.close(chan)
  end

  test "open channel with channel number and custom_consumer", meta do
    assert {:ok, chan} =
             Channel.open(meta[:conn], {AMQP.DirectConsumer, self()}, 12)

    assert {AMQP.DirectConsumer, _pid} = chan.custom_consumer
    assert :ok = Channel.close(chan)
  end
end
