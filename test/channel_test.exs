defmodule ChannelTest do
  use ExUnit.Case

  alias AMQP.Connection
  alias AMQP.Channel

  setup do
    {:ok, conn} = Connection.open
    on_exit fn -> :ok = Connection.close(conn) end
    {:ok, conn: conn}
  end

  test "open channel", meta do
    assert {:ok, chan} = Channel.open(meta[:conn])
    assert :ok = Channel.close(chan)
  end
end
