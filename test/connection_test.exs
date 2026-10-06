defmodule ConnectionTest do
  use ExUnit.Case
  import AMQP.Core
  alias AMQP.Connection

  test "connection information and keys" do
    {:ok, conn} = Connection.open(name: "inspection-test")
    on_exit(fn -> Connection.close(conn) end)

    assert :num_channels in Connection.info_keys()
    assert :heartbeat in Connection.info_keys(conn)

    assert [num_channels: 0, is_closing: false] ==
             Connection.info(conn, [:num_channels, :is_closing])

    assert "inspection-test" == Connection.connection_name(conn)

    {:ok, channel} = AMQP.Channel.open(conn)
    assert [num_channels: 1] == Connection.info(conn, [:num_channels])
    assert :ok = AMQP.Channel.close(channel)
  end

  test "unnamed connection returns undefined" do
    {:ok, conn} = Connection.open()
    assert :undefined == Connection.connection_name(conn)
    assert :ok = Connection.close(conn)
  end

  test "close with timeout" do
    {:ok, conn} = Connection.open()
    ref = Process.monitor(conn.pid)
    assert :ok = Connection.close(conn, 5_000)
    assert_receive {:DOWN, ^ref, :process, _, {:shutdown, :normal}}
  end

  test "close with reply code and text" do
    {:ok, conn} = Connection.open()
    ref = Process.monitor(conn.pid)
    assert :ok = Connection.close(conn, 320, "maintenance")

    assert_receive {:DOWN, ^ref, :process, _,
                    {:shutdown, {:app_initiated_close, 320, "maintenance"}}}
  end

  test "close with reply code, text and timeout" do
    {:ok, conn} = Connection.open()
    ref = Process.monitor(conn.pid)
    assert :ok = Connection.close(conn, 320, "maintenance", 5_000)

    assert_receive {:DOWN, ^ref, :process, _,
                    {:shutdown, {:app_initiated_close, 320, "maintenance"}}}
  end

  test "blocked notifications are forwarded and the handler can be replaced" do
    {:ok, conn} = Connection.open()
    parent = self()

    handler =
      spawn(fn ->
        receive do
          message -> send(parent, {:forwarded, message})
        end

        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn ->
      Connection.close(conn)
      send(handler, :stop)
    end)

    assert :ok = Connection.register_blocked_handler(conn, handler)
    # Inject the same protocol notification dispatched by the connection reader.
    :gen_server.cast(conn.pid, {:method, {:"connection.blocked", "test alarm"}, :none, :noflow})
    assert_receive {:forwarded, {:"connection.blocked", "test alarm"}}

    assert :ok = Connection.register_blocked_handler(conn, self())
    :gen_server.cast(conn.pid, {:method, {:"connection.unblocked"}, :none, :noflow})
    assert_receive {:"connection.unblocked"}
  end

  test "open connection with default settings" do
    assert {:ok, conn} = Connection.open()
    assert :ok = Connection.close(conn)
  end

  test "open connection with host as binary" do
    assert {:ok, conn} = Connection.open(host: "localhost", port: 5672)
    assert :ok = Connection.close(conn)
  end

  test "open connection with port as binary" do
    assert {:ok, conn} = Connection.open(host: "localhost", port: "5672")
    assert :ok = Connection.close(conn)
  end

  test "open connection with host as char list" do
    assert {:ok, conn} = Connection.open(host: ~c"localhost")
    assert :ok = Connection.close(conn)
  end

  test "open connection using uri" do
    assert {:ok, conn} = Connection.open("amqp://localhost")
    assert :ok = Connection.close(conn)
  end

  test "open connection using both uri and options" do
    assert {:ok, conn} = Connection.open("amqp://nonexistent:5672", host: ~c"localhost")
    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, port as an integer, and options " do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent",
               host: ~c"localhost",
               port: 5672
             )

    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, port as a string, and options" do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent",
               host: ~c"localhost",
               port: "5672"
             )

    assert :ok = Connection.close(conn)
  end

  test "open connection with name in options" do
    assert {:ok, conn} = Connection.open("amqp://localhost", name: "my-connection")
    assert get_connection_name(conn) == "my-connection"
    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, name, and options (deprecated but still supported)" do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent:5672", "my-connection", host: ~c"localhost")

    assert :ok = Connection.close(conn)
  end

  test "override uri with options" do
    uri = "amqp://foo:bar@amqp.test.com:12345"
    {:ok, amqp_params} = uri |> String.to_charlist() |> :amqp_uri.parse()
    record = Connection.merge_options_to_amqp_params(amqp_params, username: "me")
    params = amqp_params_network(record)

    assert params[:username] == "me"
    assert params[:password] == "bar"
    assert params[:host] == ~c"amqp.test.com"
  end

  test "update the secret of an open connection" do
    {:ok, conn} = Connection.open()
    assert :ok = Connection.update_secret(conn, "guest", "token refresh")
    assert Process.alive?(conn.pid)
    assert :ok = Connection.close(conn)
  end

  defp get_connection_name(conn) do
    params = :amqp_connection.info(conn.pid, [:amqp_params])[:amqp_params]
    amqp_params_network(client_properties: props) = params
    {_, _, name} = Enum.find(props, fn {key, _type, _value} -> key == "connection_name" end)
    name
  end
end
