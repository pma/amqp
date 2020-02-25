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

  test "open connection with uri, name, and options" do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent:5672", "my-connection", host: 'localhost')

    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, name, port as an integer, and options " do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent", "my-connection",
               host: 'localhost',
               port: 5672
             )

    assert :ok = Connection.close(conn)
  end

  test "open connection with uri, name, port as a string, and options " do
    assert {:ok, conn} =
             Connection.open("amqp://nonexistent", "my-connection",
               host: 'localhost',
               port: "5672"
             )

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
end
