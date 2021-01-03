defmodule AMQP.Application.ConnectionTest do
  use ExUnit.Case
  alias AMQP.Application.Connection, as: AppConn

  test "opens and accesses connections" do
    opts = [proc_name: :my_conn, retry_interval: 10_000, url: "amqp://guest:guest@localhost"]
    {:ok, pid} = AppConn.start_link(opts)

    {:ok, conn} = AppConn.get_connection(:my_conn)
    assert %AMQP.Connection{} = conn

    Process.exit(pid, :normal)
  end

  test "reconnects when the connection is gone" do
    {:ok, _pid} = AppConn.start_link([])
    {:ok, %AMQP.Connection{} = conn1} = AppConn.get_connection()
    AMQP.Connection.close(conn1)
    :timer.sleep(50)

    assert {:ok, %AMQP.Connection{} = conn2} = AppConn.get_connection()
    refute conn1 == conn2
  end
end
