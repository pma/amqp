defmodule AMQP.Application.ChnnelTest do
  use ExUnit.Case
  alias AMQP.Application.Connection, as: AppConn
  alias AMQP.Application.Channel, as: AppChan

  setup do
    {:ok, app_conn_pid} = AppConn.start([])

    on_exit(fn ->
      GenServer.stop(app_conn_pid)
    end)

    [app_conn: app_conn_pid]
  end

  test "opens and accesses channel" do
    opts = [connection: :default, proc_name: :test_chan]
    {:ok, pid} = AppChan.start_link(opts)

    assert {:ok, %AMQP.Channel{}} = AppChan.get_channel(:test_chan)
    GenServer.stop(pid, :normal)
  end

  test "reconnects when the channel is gone" do
    opts = [connection: :default, proc_name: :test_chan]
    {:ok, pid} = AppChan.start_link(opts)
    {:ok, %AMQP.Channel{} = chan1} = AppChan.get_channel(:test_chan)
    AMQP.Channel.close(chan1)
    :timer.sleep(50)

    assert {:ok, %AMQP.Channel{} = chan2} = AppChan.get_channel(:test_chan)
    refute chan1 == chan2
    GenServer.stop(pid)
  end

  test "AMQP connection alives when Application channel process exits" do
    opts = [connection: :default, proc_name: :test_chan]
    {:ok, pid} = AppChan.start_link(opts)
    Process.unlink(pid)
    {:ok, conn} = AppConn.get_connection()

    Process.exit(pid, :normal)
    :timer.sleep(50)
    assert Process.alive?(conn.pid)
  end

  test "reconnects when the AMQP channel is killed" do
    opts = [connection: :default, proc_name: :test_chan, retry_interval: 50]
    {:ok, pid} = AppChan.start_link(opts)
    {:ok, %AMQP.Channel{} = chan1} = AppChan.get_channel(:test_chan)
    Process.exit(chan1.pid, :kill)
    :timer.sleep(100)

    {:ok, %AMQP.Channel{} = chan2} = AppChan.get_channel(:test_chan)
    # Note the new channel also uses new connection.
    # Since the chan1 was not closed safely, the connection would also die and restarted.
    refute chan1.pid == chan2.pid
    GenServer.stop(pid)
  end

  test "AMQP channel dies when Application Channel process is killed" do
    opts = [connection: :default, proc_name: :test_chan]
    {:ok, pid} = AppChan.start_link(opts)
    Process.unlink(pid)
    {:ok, conn1} = AppConn.get_connection()

    {:ok, %AMQP.Channel{} = chan} = AppChan.get_channel(:test_chan)
    Process.exit(pid, :kill)
    :timer.sleep(50)
    refute Process.alive?(chan.pid)

    # Note that the connection is also reset when channel is killed.
    # With a kill signal, the Application.Channel can not call the Channel.close.
    # This causes the connection to be reset.
    refute Process.alive?(conn1.pid)
    {:ok, conn2} = AppConn.get_connection()
    assert Process.alive?(conn2.pid)
  end

  test "Unavailable channel does not crash" do
    assert {:error, :channel_not_found} ==
             AppChan.get_channel(:non_existing)
  end
end
