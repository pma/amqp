defmodule ConnectionTest do
  use ExUnit.Case
  import AMQP.Core
  alias AMQP.Connection

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
    assert {:ok, conn} = Connection.open(host: 'localhost')
    assert :ok = Connection.close(conn)
  end

  test "open connection using uri" do
    assert {:ok, conn} = Connection.open("amqp://localhost")
    assert :ok = Connection.close(conn)
  end

  test "open connection using both uri and options" do
    assert {:ok, conn} = Connection.open("amqp://nonexistent:5672", host: 'localhost')
    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, port as an integer, and options " do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent",
               host: 'localhost',
               port: 5672
             )

    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, port as a string, and options" do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent",
               host: 'localhost',
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
             Connection.open("amqp://nonexistent:5672", name: "my-connection", host: 'localhost')

    assert :ok = Connection.close(conn)
  end

  test "override uri with options" do
    uri = "amqp://foo:bar@amqp.test.com:12345"
    {:ok, amqp_params} = uri |> String.to_charlist() |> :amqp_uri.parse()
    record = Connection.merge_options_to_amqp_params(amqp_params, username: "me")
    params = amqp_params_network(record)

    assert params[:username] == "me"
    assert params[:password] == "bar"
    assert params[:host] == 'amqp.test.com'
  end

  defp get_connection_name(conn) do
    params = :amqp_connection.info(conn.pid, [:amqp_params])[:amqp_params]
    amqp_params_network(client_properties: props) = params
    {_, _, name} = Enum.find(props, fn {key, _type, _value} -> key == "connection_name" end)
    name
  end
end
