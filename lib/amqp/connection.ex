defmodule AMQP.Connection do
  @moduledoc """
  Functions to operate on Connections.
  """

  import AMQP.Core

  alias AMQP.Connection

  defstruct [:pid]
  @type t :: %Connection{pid: pid}

  @doc """
  Opens a new connection.

  Behaves like `open/2` but takes only either AMQP URI or options.

  ## Examples

      iex> options = [host: "localhost", port: 5672, virtual_host: "/", username: "guest", password: "guest"]
      iex> AMQP.Connection.open(options)
      {:ok, %AMQP.Connection{}}

      iex> AMQP.Connection.open("amqp://guest:guest@localhost")
      {:ok, %AMQP.Connection{}}

  """
  @spec open(keyword | String.t()) :: {:ok, t()} | {:error, atom()} | {:error, any()}
  def open(uri_or_options \\ []) when is_binary(uri_or_options) or is_list(uri_or_options) do
    open(uri_or_options, :undefined)
  end

  @doc """
  Opens an new Connection to an AMQP broker.

  The connections created by this module are supervised under  amqp_client's
  supervision tree.  Please note that connections do not get restarted
  automatically by the supervision tree in case of a failure. If you need
  robust connections and channels, use monitors on the returned connection PID.

  ## Options

    * `:username` - The name of a user registered with the broker (default
      `"guest"`)

    * `:password` - The password of user (default to `"guest"`)

    * `:virtual_host` - The name of a virtual host in the broker (defaults
      `"/"`)

    * `:host` - The hostname of the broker (default `"localhost"`)

    * `:port` - The port the broker is listening on (default `5672`)

    * `:channel_max` - The channel_max handshake parameter (default `0`)

    * `:frame_max` - The frame_max handshake parameter (defaults `0`)

    * `:heartbeat` - The hearbeat interval in seconds (defaults `10`)

    * `:connection_timeout` - The connection timeout in milliseconds (efaults
      `50000`)

    * `:ssl_options` - Enable SSL by setting the location to cert files
      (default `:none`)

    * `:client_properties` - A list of extra client properties to be sent to
      the server (default `[]`)

    * `:socket_options` - Extra socket options. These are appended to the
      default options. See http://www.erlang.org/doc/man/inet.html#setopts-2 and
      http://www.erlang.org/doc/man/gen_tcp.html#connect-4 for descriptions of
      the available options

    * `:auth_mechanisms` - A list of authentication of SASL authentication
      mechanisms to use. See
      https://www.rabbitmq.com/access-control.html#mechanisms and
      https://github.com/rabbitmq/rabbitmq-auth-mechanism-ssl for descriptions of
      the available options

    * `:name` - A human-readable string that will be displayed in the
      management UI. Connection names do not have to be unique and cannot be
      used as connection identifiers (default `:undefined`)

  ## Examples

      iex> options = [host: "localhost", port: 5672, virtual_host: "/", username: "guest", password: "guest", name: "my-conn"]
      iex> AMQP.Connection.open(options)
      {:ok, %AMQP.Connection{}}

      iex> AMQP.Connection.open("amqp://guest:guest@localhost", port: 5673)
      {:ok, %AMQP.Connection{}}

  ## Enabling SSL

  To enable SSL, supply the following in the `ssl_options` field:

    * `:cacertfile` - Specifies the certificates of the root Certificate
      Authorities that we wish to implicitly trust

    * `:certfile` - The client's own certificate in PEM format

    * `:keyfile` - The client's private key in PEM format

  Here is an example:

      iex> AMQP.Connection.open(
        port: 5671,
        ssl_options: [
          cacertfile: '/path/to/testca/cacert.pem',
          certfile: '/path/to/client/cert.pem',
          keyfile: '/path/to/client/key.pem',
          # only necessary with intermediate CAs
          # depth: 2,
          verify: :verify_peer,
          fail_if_no_peer_cert: true
        ]
      )

  ## Backward compatibility for connection name

  RabbitMQ supports user-specified connection names since version 3.6.2.

  Previously AMQP took a connection name as a separate parameter on `open/2`
  and `open/3` and it is still supported in this version.

      iex> options = [host: "localhost", port: 5672, virtual_host: "/", username: "guest", password: "guest"]
      iex> AMQP.Connection.open(options, :undefined)
      {:ok, %AMQP.Connection{}}

      iex> AMQP.Connection.open("amqp://guest:guest@localhost", "my-connection")
      {:ok, %AMQP.Connection{}}

      iex> AMQP.Connection.open("amqp://guest:guest@localhost", "my-connection", options)
      {:ok, %AMQP.Connection{}}

  However the connection name parameter is now deprecated and might not be
  supported in the future versions.

  You are recommended to pass it with `:name` option instead:

      iex> AMQP.Connection.open("amqp://guest:guest@localhost", name: "my-connection")
      {:ok, %AMQP.Connection{}}

  """
  @spec open(String.t() | keyword, keyword | String.t() | :undefined) ::
          {:ok, t()} | {:error, atom()} | {:error, any()}
  def open(uri, options)

  def open(uri, name) when is_binary(uri) and (is_binary(name) or name == :undefined) do
    do_open(uri, name, _options = [])
  end

  def open(options, name) when is_list(options) and (is_binary(name) or name == :undefined) do
    {name_from_opts, options} = take_connection_name(options)
    name = if name == :undefined, do: name_from_opts, else: name

    options
    |> merge_options_to_default()
    |> do_open(name)
  end

  def open(uri, options) when is_binary(uri) and is_list(options) do
    {name, options} = take_connection_name(options)

    do_open(uri, name, options)
  end

  @doc false
  @deprecated "Use :name in open/2 instead"
  @spec open(String.t(), String.t() | :undefined, keyword) ::
          {:ok, t()} | {:error, atom()} | {:error, any()}
  def open(uri, name, options) when is_binary(uri) and is_list(options) do
    do_open(uri, name, options)
  end

  defp do_open(uri, name, options) do
    case uri |> String.to_charlist() |> :amqp_uri.parse() do
      {:ok, amqp_params} -> amqp_params |> merge_options_to_amqp_params(options) |> do_open(name)
      error -> error
    end
  end

  defp do_open(amqp_params, name) do
    case :amqp_connection.start(amqp_params, name) do
      {:ok, pid} -> {:ok, %Connection{pid: pid}}
      error -> error
    end
  end

  # take name from options
  defp take_connection_name(options) do
    name = options[:name] || :undefined
    options = Keyword.delete(options, :name)
    {name, options}
  end

  @doc false
  @spec merge_options_to_amqp_params(tuple, keyword) :: tuple
  def merge_options_to_amqp_params(amqp_params, options) do
    options = normalize_ssl_options(options)
    params = amqp_params_network(amqp_params)

    amqp_params_network(
      username: keys_get(options, params, :username),
      password: keys_get(options, params, :password),
      virtual_host: keys_get(options, params, :virtual_host),
      host: keys_get(options, params, :host) |> to_charlist(),
      port: keys_get(options, params, :port) |> normalize_int_opt(),
      channel_max: keys_get(options, params, :channel_max) |> normalize_int_opt(),
      frame_max: keys_get(options, params, :frame_max) |> normalize_int_opt(),
      heartbeat: keys_get(options, params, :heartbeat) |> normalize_int_opt(),
      connection_timeout: keys_get(options, params, :connection_timeout) |> normalize_int_opt(),
      ssl_options: keys_get(options, params, :ssl_options),
      client_properties: keys_get(options, params, :client_properties),
      socket_options: keys_get(options, params, :socket_options),
      auth_mechanisms: keys_get(options, params, :auth_mechanisms)
    )
  end

  # Gets the value from k1. If empty, gets the value from k2.
  defp keys_get(k1, k2, key) do
    Keyword.get(k1, key, Keyword.get(k2, key))
  end

  defp merge_options_to_default(options) do
    amqp_params_network(
      username: Keyword.get(options, :username, "guest"),
      password: Keyword.get(options, :password, "guest"),
      virtual_host: Keyword.get(options, :virtual_host, "/"),
      host: Keyword.get(options, :host, 'localhost') |> to_charlist(),
      port: Keyword.get(options, :port, :undefined) |> normalize_int_opt(),
      channel_max: Keyword.get(options, :channel_max, 0) |> normalize_int_opt(),
      frame_max: Keyword.get(options, :frame_max, 0) |> normalize_int_opt(),
      heartbeat: Keyword.get(options, :heartbeat, 10) |> normalize_int_opt(),
      connection_timeout: Keyword.get(options, :connection_timeout, 50000) |> normalize_int_opt(),
      ssl_options: Keyword.get(options, :ssl_options, :none),
      client_properties: Keyword.get(options, :client_properties, []),
      socket_options: Keyword.get(options, :socket_options, []),
      auth_mechanisms:
        Keyword.get(options, :auth_mechanisms, [
          &:amqp_auth_mechanisms.plain/3,
          &:amqp_auth_mechanisms.amqplain/3
        ])
    )
  end

  # If an integer value is configured as a string, cast it to an integer where
  # applicable
  defp normalize_int_opt(value) when is_binary(value), do: String.to_integer(value)
  defp normalize_int_opt(value), do: value

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
