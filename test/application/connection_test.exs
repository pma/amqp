defmodule AMQP.Application.ConnectionTest do
  use ExUnit.Case
  alias AMQP.Application.Connection, as: AppConn

  test "opens and accesses connections" do
    opts = [proc_name: :my_conn, retry_interval: 10_000, url: "amqp://guest:guest@localhost"]
    {:ok, pid} = AppConn.start_link(opts)

    {:ok, conn} = AppConn.get_connection(:my_conn)
    assert %AMQP.Connection{} = conn

    GenServer.stop(pid)
  end

  test "reconnects when the connection is gone" do
    {:ok, pid} = AppConn.start_link([])
    {:ok, %AMQP.Connection{} = conn1} = AppConn.get_connection()
    AMQP.Connection.close(conn1)
    :timer.sleep(50)

    assert {:ok, %AMQP.Connection{} = conn2} = AppConn.get_connection()
    refute conn1 == conn2
    GenServer.stop(pid)
  end

  test "reconnects when the AMQP connection is killed" do
    {:ok, pid} = AppConn.start_link([])
    {:ok, %AMQP.Connection{pid: conn_pid} = conn1} = AppConn.get_connection()
    Process.exit(conn_pid, :kill)
    :timer.sleep(50)

    assert {:ok, %AMQP.Connection{} = conn2} = AppConn.get_connection()
    refute conn1 == conn2
    GenServer.stop(pid)
  end

  test "AMQP connection dies when Connection process is killed" do
    {:ok, pid} = AppConn.start_link([])
    Process.unlink(pid)
    {:ok, %AMQP.Connection{pid: conn_pid}} = AppConn.get_connection()
    Process.exit(pid, :kill)
    :timer.sleep(50)
    refute Process.alive?(conn_pid)
  end

  test "Unavailable connection does not crash" do
    assert {:error, :connection_not_found} ==
             AppConn.get_connection(:non_existing)
  end
end
