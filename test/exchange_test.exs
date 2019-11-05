defmodule ExchangeTest do
  use ExUnit.Case

  alias AMQP.Connection
  alias AMQP.Channel
  alias AMQP.Exchange

  setup do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    on_exit(fn -> :ok = Connection.close(conn) end)
    {:ok, conn: conn, chan: chan}
  end

  test "declare exchange with defaults", meta do
    name = rand_name()
    assert :ok = Exchange.declare(meta[:chan], name)
    assert :ok = Exchange.delete(meta[:chan], name)
  end

  test "declare exchange with type direct", meta do
    name = rand_name()
    assert :ok = Exchange.declare(meta[:chan], name, :direct)
    assert :ok = Exchange.delete(meta[:chan], name)
  end

  test "declare exchange with type topic", meta do
    name = rand_name()
    assert :ok = Exchange.declare(meta[:chan], name, :topic)
    assert :ok = Exchange.delete(meta[:chan], name)
  end

  test "declare exchange with type fanout", meta do
    name = rand_name()
    assert :ok = Exchange.declare(meta[:chan], name, :fanout)
    assert :ok = Exchange.delete(meta[:chan], name)
  end

  test "declare exchange with type headers", meta do
    name = rand_name()
    assert :ok = Exchange.declare(meta[:chan], name, :headers)
    assert :ok = Exchange.delete(meta[:chan], name)
  end

  test "declare direct exchange with convenience function", meta do
    name = rand_name()
    assert :ok = Exchange.direct(meta[:chan], name)
    assert :ok = Exchange.delete(meta[:chan], name)
  end

  test "declare fanout exchange with convenience function", meta do
    name = rand_name()
    assert :ok = Exchange.fanout(meta[:chan], name)
    assert :ok = Exchange.delete(meta[:chan], name)
  end

  test "declare topic exchange with convenience function", meta do
    name = rand_name()
    assert :ok = Exchange.topic(meta[:chan], name)
    assert :ok = Exchange.delete(meta[:chan], name)
  end

  test "bind and unbind exchange to/from another exchange", meta do
    destination = rand_name()
    source = rand_name()
    assert :ok = Exchange.fanout(meta[:chan], destination)
    assert :ok = Exchange.fanout(meta[:chan], source)
    assert :ok = Exchange.bind(meta[:chan], destination, source)
    assert :ok = Exchange.unbind(meta[:chan], destination, source)
    assert :ok = Exchange.delete(meta[:chan], destination)
    assert :ok = Exchange.delete(meta[:chan], source)
  end

  defp rand_name do
    :crypto.strong_rand_bytes(8) |> Base.encode64()
  end
end
