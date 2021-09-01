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
end
