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

  test "basic return", meta do
    :ok = Basic.return(meta[:chan], self())

    exchange = ""
    routing_key = "non-existent-queue"
    payload = "payload"

    Basic.publish(meta[:chan], exchange, routing_key, payload, mandatory: true)

    assert_receive {:basic_return,
                     ^payload,
                     %{routing_key: ^routing_key,
                       exchange: ^exchange,
                       reply_text: "NO_ROUTE"}}

    :ok = Basic.cancel_return(meta[:chan])

    Basic.publish(meta[:chan], exchange, routing_key, payload, mandatory: true)

    refute_receive {:basic_return, _payload, _properties}
  end
end
