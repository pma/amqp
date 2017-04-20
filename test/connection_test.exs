defmodule ConnectionTest do
  use ExUnit.Case

  alias AMQP.Connection

  test "open direct connection" do
    # This test assumes that we have a running RabbitMQ with short
    # nodename 'rabbit@localhost', and that it uses the same Erlang
    # cookie as we do. And it's better to have RabbitMQ of version
    # equal to that of amqp_client library used. We can achieve this
    # with following sequence of commands under the same user that
    # will run the test-suite:
    #
    # wget https://github.com/rabbitmq/rabbitmq-server/releases/download/rabbitmq_v3_6_9/rabbitmq-server-generic-unix-3.6.9.tar.xz
    # tar xJvf rabbitmq-server-generic-unix-3.6.9.tar.xz
    # cd rabbitmq_server-3.6.9
    # RABBITMQ_NODENAME=rabbit@localhost ./sbin/rabbitmq-server
    :ok = ensure_distribution()
    assert {:ok, conn} = Connection.open_direct node: :rabbit@localhost
    assert :ok = Connection.close(conn)
  end

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

  defp ensure_distribution() do
    # Attempt to start distribution with a name randomly selected from
    # a small pool of names (to prevent atom table exhausting in
    # servers we'll connect to). Several attemps are made in case we
    # are running some tests in parallel. This is taken almost
    # directly from rabbit_cli.erl (skipping a bizzare FQDN magic).
    case node() do
      :nonode@nohost -> start_distribution_anon(10, :undefined)
      _ -> :ok
    end
  end

  defp start_distribution_anon(0, last_error) do
    {:error, last_error}
  end
  defp start_distribution_anon(tries_left, _) do
    name_candidate = generate_node_name()
    case :net_kernel.start([name_candidate, :shortnames]) do
      {:ok, _} -> :ok
      {:error, reason} ->
        start_distribution_anon(tries_left - 1, reason)
    end
  end

  defp generate_node_name() do
    :io_lib.format("amqp-mix-test-~2..0b", [:rand.uniform(100)])
    |> :lists.flatten
    |> :erlang.list_to_atom
  end

end
