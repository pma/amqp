defmodule BasicTest do
  use ExUnit.Case

  alias AMQP.Connection
  alias AMQP.Channel
  alias AMQP.Basic

  setup do
    {:ok, conn} = Connection.open
    {:ok, chan} = Channel.open(conn)
    on_exit fn -> :ok = Connection.close(conn) end
    {:ok, conn: conn, chan: chan}
  end

  test "basic publish to default exchange", meta do
    assert :ok = Basic.publish(meta[:chan], "", "", "ping")
  end
end
