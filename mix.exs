defmodule AMQP.Mixfile do
  use Mix.Project

  @source_url "https://github.com/pma/amqp"
  @version "4.0.0"

  def project do
    [
      app: :amqp,
      version: @version,
      elixir: "~> 1.14",
      package: package(),
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      preferred_cli_env: preferred_cli_env(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      applications: start_applications(Mix.env()),
      mod: {AMQP.Application, []}
    ]
  end

  defp start_applications(:docs) do
    [:logger, :makeup, :makeup_elixir, :makeup_erlang, :ex_doc, :amqp_client]
  end

  defp start_applications(_env), do: [:amqp_client, :logger]

  defp deps do
    [
      {:amqp_client, "~> 4.0"},

      # Docs dependencies.
      {:ex_doc, ">= 0.0.0", only: :docs},
      {:inch_ex, "~> 2.0", only: :docs},

      # Dev dependencies.
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end

  defp package do
    [
      description: description(),
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Paulo Almeida", "Eduardo Gurgel", "Tatsuya Ono"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://github.com/pma/amqp/releases",
        "GitHub" => @source_url
      }
    ]
  end

  defp description do
    """
    Idiomatic Elixir client for RabbitMQ.
    """
  end

  defp dialyzer do
    [
      ignore_warnings: "dialyzer.ignore-warnings",
      plt_add_deps: :transitive,
      flags: [:error_handling, :race_conditions, :no_opaque, :underspecs]
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end

  defp preferred_cli_env do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
      docs: :docs
    ]
  end
end
