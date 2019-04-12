defmodule AMQP.Connection do
  @moduledoc """
  Functions to operate on Connections.
  """

  import AMQP.Core

  alias AMQP.Connection

  defstruct [:pid]
  @type t :: %Connection{pid: pid}

  @doc """
  Opens an new Connection to an AMQP broker.

  The connections created by this module are supervised under  amqp_client's supervision tree.
  Please note that connections do not get restarted automatically by the supervision tree in
  case of a failure. If you need robust connections and channels, use monitors on the returned
  connection PID.

  The connection parameters can be passed as a keyword list or as a AMQP URI.

  When using a keyword list, the following options can be used:

  # Options

    * `:username` - The name of a user registered with the broker (defaults to \"guest\");
    * `:password` - The password of user (defaults to \"guest\");
    * `:virtual_host` - The name of a virtual host in the broker (defaults to \"/\");
    * `:host` - The hostname of the broker (defaults to \"localhost\");
    * `:port` - The port the broker is listening on (defaults to `5672`);
    * `:channel_max` - The channel_max handshake parameter (defaults to `0`);
    * `:frame_max` - The frame_max handshake parameter (defaults to `0`);
    * `:heartbeat` - The hearbeat interval in seconds (defaults to `10`);
    * `:connection_timeout` - The connection timeout in milliseconds (defaults to `50000`);
    * `:ssl_options` - Enable SSL by setting the location to cert files (defaults to `:none`);
    * `:client_properties` - A list of extra client properties to be sent to the server, defaults to `[]`;
    * `:socket_options` - Extra socket options. These are appended to the default options. \
                          See http://www.erlang.org/doc/man/inet.html#setopts-2 and http://www.erlang.org/doc/man/gen_tcp.html#connect-4 \
                          for descriptions of the available options.

  ## Enabling SSL

  To enable SSL, supply the following in the `ssl_options` field:

    * `cacertfile` - Specifies the certificates of the root Certificate Authorities that we wish to implicitly trust;
    * `certfile` - The client's own certificate in PEM format;
    * `keyfile` - The client's private key in PEM format;

  ### Example

  ```
  AMQP.Connection.open port: 5671,
                       ssl_options: [cacertfile: '/path/to/testca/cacert.pem',
                                     certfile: '/path/to/client/cert.pem',
                                     keyfile: '/path/to/client/key.pem',
                                     # only necessary with intermediate CAs
                                     # depth: 2,
                                     verify: :verify_peer,
                                     fail_if_no_peer_cert: true]
  ```

  # Connection name
  RabbitMQ supports user-specified connection names since version 3.6.2.

  Connection names are human-readable strings that will be displayed in the management UI.
  Connection names do not have to be unique and cannot be used as connection identifiers.

  ## Examples

      iex> AMQP.Connection.open host: \"localhost\", port: 5672, virtual_host: \"/\", username: \"guest\", password: \"guest\"
      {:ok, %AMQP.Connection{}}

      iex> AMQP.Connection.open \"amqp://guest:guest@localhost\"
      {:ok, %AMQP.Connection{}}

      iex> AMQP.Connection.open \"amqp://guest:guest@localhost\", \"a-connection-with-a-name\"
      {:ok, %AMQP.Connection{}}
  """
  @spec open(keyword|String.t, String.t|:undefined) :: {:ok, t} | {:error, atom} | {:error, any}
  def open(options \\ [], name \\ :undefined)

  def open(options, name) when is_list(options) do
    options = options
    |> normalize_ssl_options

    amqp_params =
      amqp_params_network(username:           Keyword.get(options, :username,           "guest"),
                          password:           Keyword.get(options, :password,           "guest"),
                          virtual_host:       Keyword.get(options, :virtual_host,       "/"),
                          host:               Keyword.get(options, :host,               'localhost') |> to_charlist,
                          port:               Keyword.get(options, :port,               :undefined),
                          channel_max:        Keyword.get(options, :channel_max,        0),
                          frame_max:          Keyword.get(options, :frame_max,          0),
                          heartbeat:          Keyword.get(options, :heartbeat,          10),
                          connection_timeout: Keyword.get(options, :connection_timeout, 50000),
                          ssl_options:        Keyword.get(options, :ssl_options,        :none),
                          client_properties:  Keyword.get(options, :client_properties,  []),
                          socket_options:     Keyword.get(options, :socket_options,     []),
                          auth_mechanisms:    Keyword.get(options, :auth_mechanisms,    [&:amqp_auth_mechanisms.plain/3, &:amqp_auth_mechanisms.amqplain/3]))

    do_open(amqp_params, name)
  end

  def open(uri, name) when is_binary(uri) do
    case uri |> to_charlist |> :amqp_uri.parse do
      {:ok, amqp_params} -> do_open(amqp_params, name)
      error              -> error
    end
  end

  @doc """
  Closes an open Connection.
  """
  @spec close(t) :: :ok | {:error, any}
  def close(conn) do
    case :amqp_connection.close(conn.pid) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  defp do_open(amqp_params, name) do
    case :amqp_connection.start(amqp_params, name) do
      {:ok, pid} -> {:ok, %Connection{pid: pid}}
      error      -> error
    end
  end

  defp normalize_ssl_options(options) when is_list(options) do
    for {k, v} <- options do
      if k in [:cacertfile, :certfile, :keyfile] do
        {k, to_charlist(v)}
      else
        {k, v}
      end
    end
  end
  defp normalize_ssl_options(options), do: options
end
