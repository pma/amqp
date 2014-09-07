defmodule AMQP.Connection do
  @moduledoc """
  Functions to operate on Connections.
  """

  import Record
  import AMQP.Core
  alias __MODULE__

  defstruct [:pid]

  @doc """
  Opens an new Connection to an AMQP broker.

  The connection parameters can be passed as a keyword list or as a AMQP URI.
  When using a keyword list, the options `host`, `port`, `virtual_host`,
  `username` and `password` can be used.

  ## Examples

      iex> AMQP.Connection.open host: \"localhost\", port: 5672, virtual_host: \"/\", username: \"guest\", password: \"guest\"
      {:ok, %AMQP.Connection{}}
  """
  def open(options \\ [])

  def open(options) when is_list(options) do
    amqp_params_network(username:           Keyword.get(options, :username,           "guest"),
                        password:           Keyword.get(options, :password,           "guest"),
                        virtual_host:       Keyword.get(options, :virtual_host,       "/"),
                        host:               Keyword.get(options, :host,               'localhost') |> normalize_host,
                        port:               Keyword.get(options, :port,               :undefined),
                        channel_max:        Keyword.get(options, :channel_max,        0),
                        frame_max:          Keyword.get(options, :frame_max,          0),
                        heartbeat:          Keyword.get(options, :heartbeat,          0),
                        connection_timeout: Keyword.get(options, :connection_timeout, :infinity),
                        ssl_options:        Keyword.get(options, :ssl_options,        :none),
                        auth_mechanisms:    Keyword.get(options, :auth_mechanisms,    [&:amqp_auth_mechanisms.plain/3,
                                                                                       &:amqp_auth_mechanisms.amqplain/3]),
                        client_properties:  Keyword.get(options, :client_properties,  []),
                        socket_options:     Keyword.get(options, :socket_options,     []))
    |> do_open
  end

  def open(uri) when is_binary(uri) do
    case String.to_char_list(uri) |> :amqp_uri.parse do
      {:ok, amqp_params} -> do_open(amqp_params)
      error              -> error
    end
  end

  @doc """
  Closes an open Connection.
  """
  def close(conn), do: :amqp_connection.close(conn.pid)

  defp do_open(amqp_params) when is_record(amqp_params) do
    case :amqp_connection.start(amqp_params) do
      {:ok, pid} -> {:ok, %Connection{pid: pid}}
      error      -> error
    end
  end

  defp normalize_host(host) do
    cond do
      is_binary(host) -> String.to_char_list(host)
      true            -> host
    end
  end

end
