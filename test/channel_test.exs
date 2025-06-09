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

  test "open channel with channel number only", meta do
    assert {:ok, chan} = Channel.open(meta[:conn], channel_number: 90)
    assert {AMQP.SelectiveConsumer, _pid} = chan.custom_consumer
    assert :ok = Channel.close(chan)
  end

  test "open channel with custom_consumer only", meta do
    assert {:ok, chan} = Channel.open(meta[:conn], custom_consumer: {AMQP.DirectConsumer, self()})
    assert {AMQP.DirectConsumer, _pid} = chan.custom_consumer
    assert :ok = Channel.close(chan)
  end

  test "open channel with channel number and custom_consumer only", meta do
    assert {:ok, chan} =
             Channel.open(meta[:conn],
               channel_number: 12,
               custom_consumer: {AMQP.DirectConsumer, self()}
             )

    assert {AMQP.DirectConsumer, _pid} = chan.custom_consumer
    assert :ok = Channel.close(chan)
  end

  test "open channel with old custom consumer only argument", meta do
    assert {:ok, chan} = Channel.open(meta[:conn], {AMQP.DirectConsumer, self()})
    assert {AMQP.DirectConsumer, _pid} = chan.custom_consumer
    assert :ok = Channel.close(chan)
  end
end
