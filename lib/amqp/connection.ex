defmodule AMQP.Connection do
  @moduledoc """
  Functions to operate on Connections.
  """

  import AMQP.Core

  alias AMQP.Connection

  defstruct [:pid]

  @doc """
  Opens an new Connection to an AMQP broker.

  The connections created by this module are supervised under  amqp_client's supervision tree.
  Please note that connections do not get restarted automatically by the supervision tree in
  case of a failure. If you need robust connections and channels, use monitors on the returned
  connection PID.

  The connection parameters can be passed as a keyword list or as a AMQP URI.
  Or, alternatively you can set up connection parameters via config.exs.

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
  def open(options \\ [])

  def open(options) when is_list(options) do
    options = options
    |> normalize_ssl_options

    amqp_params = merge_amqp_params(options)

    do_open(amqp_params)
  end

  def open(uri) when is_binary(uri) do
    case uri |> to_char_list |> :amqp_uri.parse do
      {:ok, amqp_params} -> do_open(amqp_params)
      error              -> error
    end
  end

  @doc """
  Closes an open Connection.
  """
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
        {k, to_char_list(v)}
      else
        {k, v}
      end
    end
  end
  defp normalize_ssl_options(options), do: options

  @app_name Mix.Project.config[:app]

  defp app_setting(name) do
    Application.get_env(@app_name, name, nil)
  end

  defp merge_amqp_params(options) do
    username           = Keyword.get(options,  :username)           || app_setting(:username)           || "guest"
    password           = Keyword.get(options,  :password)           || app_setting(:password)           || "guest"
    virtual_host       = Keyword.get(options,  :virtual_host)       || app_setting(:virtual_host)       || "/"
    host               = (Keyword.get(options, :host)               || app_setting(:host)               || "localhost") |> to_char_list
    port               = Keyword.get(options,  :port)               || app_setting(:port)               || :undefined
    channel_max        = Keyword.get(options,  :channel_max)        || app_setting(:channel_max)        || 0
    frame_max          = Keyword.get(options,  :frame_max)          || app_setting(:frame_max)          || 0
    heartbeat          = Keyword.get(options,  :heartbeat)          || app_setting(:heartbeat)          || 0
    connection_timeout = Keyword.get(options,  :connection_timeout) || app_setting(:connection_timeout) || :infinity
    ssl_options        = Keyword.get(options,  :ssl_options)        || app_setting(:ssl_options)        || :none
    client_properties  = Keyword.get(options,  :client_properties)  || app_setting(:client_properties)  || []
    socket_options     = Keyword.get(options,  :socket_options)     || app_setting(:socket_options)     || []

    amqp_params_network(username:           username,
                        password:           password,
                        virtual_host:       virtual_host,
                        host:               host,
                        port:               port,
                        channel_max:        channel_max,
                        frame_max:          frame_max,
                        heartbeat:          heartbeat,
                        connection_timeout: connection_timeout,
                        ssl_options:        ssl_options,
                        client_properties:  client_properties,
                        socket_options:     socket_options)
  end
end
