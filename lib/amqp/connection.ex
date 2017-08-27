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
    * `:heartbeat` - The hearbeat interval in seconds (defaults to `0` - turned off);
    * `:connection_timeout` - The connection timeout in milliseconds (defaults to `infinity`);
    * `:ssl_options` - Enable SSL by setting the location to cert files (defaults to `none`);
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

  ## Examples

      iex> AMQP.Connection.open host: \"localhost\", port: 5672, virtual_host: \"/\", username: \"guest\", password: \"guest\"
      {:ok, %AMQP.Connection{}}

      iex> AMQP.Connection.open \"amqp://guest:guest@localhost\"
      {:ok, %AMQP.Connection{}}

  """
  @spec open(keyword|String.t) :: {:ok, t} | {:error, atom} | {:error, any}
  def open(options \\ [])

  def open(options) when is_list(options) do
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
                          heartbeat:          Keyword.get(options, :heartbeat,          0),
                          connection_timeout: Keyword.get(options, :connection_timeout, :infinity),
                          ssl_options:        Keyword.get(options, :ssl_options,        :none),
                          client_properties:  Keyword.get(options, :client_properties,  []),
                          socket_options:     Keyword.get(options, :socket_options,     []),
                          auth_mechanisms:    Keyword.get(options, :auth_mechanisms,    [&:amqp_auth_mechanisms.plain/3, &:amqp_auth_mechanisms.amqplain/3]))

    do_open(amqp_params)
  end

  def open(uri) when is_binary(uri) do
    case uri |> to_charlist |> :amqp_uri.parse do
      {:ok, amqp_params} -> do_open(amqp_params)
      error              -> error
    end
  end

  @doc """
  Opens an new direct Connection to an AMQP broker.

  Direct connection is the special type of connection that is
  supported by RabbitMQ broker, where Erlang distribution protocol is
  used to communicate with broker. It's a bit faster than the regular
  AMQP protocol, as there is no need to serialize and deserialize AMQP
  frames (especially when we are using this library at the same BEAM
  node where the RabbitMQ runs). But it's less secure, as giving
  direct access to a client means it has full control over RabbitMQ
  node.

  The connections created by this function are not restaretd
  automatically, see open/1 for more details.

  The connection parameters are passed as a keyword list with the
  following options available:

  # Options
    * `:username` - The name of a user registered with the broker (defaults to `:none`);
    * `:password` - The password of the user (defaults to `:none`);
    * `:virtual_host` - The name of a virtual host in the broker (defaults to \"/\");
    * `:node` - Erlang node name to connect to (defaults to the current node);
    * `:client_properties` - A list of extra client properties to be sent to the server, defaults to `[]`;

  # Adapter options

  Additional details can be provided when a direct connection is used
  to provide connectivity for some non-AMQP protocol (like it happens
  in STOMP and MQTT plugins for RabbitMQ). We assume that you know
  what you are doing in this case, here is the options that maps to
  corresponding fields of `#amqp_adapter_info{}` record:
  `:adapter_host`, `:adapter_port`, `:adapter_peer_host`,
  `:adapter_peer_port`, `:adapter_name`, `:adapter_protocol`,
  `:adapter_additional_info`.

  ## Examples

      AMQP.Connection.open_direct node: :rabbit@localhost
      {:ok, %AMQP.Connection{}}

  """
  @spec open_direct(keyword) :: {:ok, t} | {:error, atom}
  def open_direct(options \\ [])

  def open_direct(options) when is_list(options) do
    adapter_info = amqp_adapter_info(
      host: Keyword.get(options, :adapter_host, :unknown),
      port: Keyword.get(options, :adapter_port, :unknown),
      peer_host: Keyword.get(options, :adapter_peer_host, :unknown),
      peer_port: Keyword.get(options, :adapter_peer_port, :unknown),
      name: Keyword.get(options, :adapter_name, :unknown),
      protocol: Keyword.get(options, :adapter_protocol, :unknown),
      additional_info: Keyword.get(options, :adapter_additional_info, []))

    amqp_params = amqp_params_direct(
      username: Keyword.get(options, :username, :none),
      password: Keyword.get(options, :password, :none),
      virtual_host: Keyword.get(options, :virtual_host, "/"),
      node: Keyword.get(options, :node, node()),
      adapter_info: adapter_info,
      client_properties: Keyword.get(options, :client_properties, []))

    do_open(amqp_params)
  end

  @doc """
  Closes an open Connection.
  """
  @spec close(t) :: :ok | {:error, atom}
  def close(conn) do
    :amqp_connection.close(conn.pid)
  end

  defp do_open(amqp_params) do
    case :amqp_connection.start(amqp_params) do
      {:ok, pid} -> {:ok, %Connection{pid: pid}}
      error      -> error
    end
  end

  defp normalize_ssl_options(options) when is_list(options) do
    for {k, v} <- options do
      if k in [:cacertfile, :cacertfile, :cacertfile] do
        {k, to_charlist(v)}
      else
        {k, v}
      end
    end
  end
  defp normalize_ssl_options(options), do: options
end
