defmodule ConsumerTest do
  use ExUnit.Case

  defmodule TestConsumer do
    use AMQP.Consumer

    def start_link(parent_pid \\ self()) do
      GenServer.start_link(__MODULE__, parent_pid)
    end

    def init(parent_pid) do
      {:ok, conn} = AMQP.Connection.open
      {:ok, chan} = AMQP.Channel.open conn
      {:ok, %{queue: queue}} = AMQP.Queue.declare(chan, "", auto_delete: true)
      {:ok, consumer_tag} = AMQP.Basic.consume(chan, queue)

      {:ok, %{chan: chan, queue: queue,  parent_pid: parent_pid, consumer_tag: consumer_tag}}
    end

    def handle_basic_deliver(payload, meta, state) do
      :ok = AMQP.Basic.ack(state.chan, meta.delivery_tag)
      send state.parent_pid, {:basic_deliver, payload}
      {:noreply, state}
    end

    def handle_basic_cancel_ok(consumer_tag, state) do
      send state.parent_pid, {:basic_cancel_ok, consumer_tag}
      {:stop, :normal, state}
    end

    def handle_basic_cancel(consumer_tag, no_wait, state) do
      send state.parent_pid, {:basic_cancel, consumer_tag, no_wait}
      {:stop, :normal, state}
    end

    def handle_call(:state, _from, state) do
      {:reply, state, state}
    end

    def state(pid) do
      GenServer.call(pid, :state)
    end
  end

  setup do
    {:ok, conn} = AMQP.Connection.open
    on_exit fn -> :ok = AMQP.Connection.close(conn) end
    {:ok, conn: conn}
  end

  test "basic deliver", meta do
    {:ok, pid} = TestConsumer.start_link
    state = TestConsumer.state(pid)
    message = :crypto.rand_bytes(16) |> Base.encode16
    {:ok, chan} = AMQP.Channel.open(meta[:conn])
    AMQP.Basic.publish(chan, "", state.queue, message)
    assert_receive({:basic_deliver, ^message})
    :ok = AMQP.Channel.close(chan)
  end

  test "basic cancel ok" do
    {:ok, pid} = TestConsumer.start_link
    assert Process.alive?(pid) == true
    state = TestConsumer.state(pid)
    c_tag = state.consumer_tag
    AMQP.Basic.cancel(state.chan, c_tag)
    assert_receive({:basic_cancel_ok, ^c_tag})
    assert Process.alive?(pid) == false
  end

  test "basic cancel on queue deleted" do
    {:ok, pid} = TestConsumer.start_link
    state = TestConsumer.state(pid)
    c_tag = state.consumer_tag
    AMQP.Queue.delete(state.chan, state.queue)
    assert_receive({:basic_cancel, ^c_tag, _})
    assert Process.alive?(pid) == false
  end

end
