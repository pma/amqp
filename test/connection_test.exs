defmodule ConnectionTest do
  use ExUnit.Case

  alias AMQP.Connection

  test "open connection with default settings" do
    assert {:ok, conn} = Connection.open
    assert :ok = Connection.close(conn)
  end

  test "open connection with host as binary" do
    assert {:ok, conn} = Connection.open host: "localhost"
    assert :ok = Connection.close(conn)
  end

  test "open connection with host as char list" do
    assert {:ok, conn} = Connection.open host: 'localhost'
    assert :ok = Connection.close(conn)
  end

  test "open connection using uri" do
    assert {:ok, conn} = Connection.open "amqp://localhost"
    assert :ok = Connection.close(conn)
  end
end
