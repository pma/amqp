defmodule AMQP.Mixfile do
  use Mix.Project

  @version "1.2.0"

  def project do
    [app: :amqp,
     version: @version,
     elixir: "~> 1.3",
     description: description(),
     package: package(),
     source_url: "https://github.com/pma/amqp",
     deps: deps(),
     dialyzer: [
       ignore_warnings: "dialyzer.ignore-warnings",
       plt_add_deps: :transitive,
       flags: [:error_handling, :race_conditions, :no_opaque, :underspecs]
     ],
     docs: [extras: ["README.md"], main: "readme",
            source_ref: "v#{@version}",
            source_url: "https://github.com/pma/amqp"]]
  end

  def application do
    [
      applications: [:lager, :amqp_client],
      mod: {AMQP.Application, []}
    ]
  end

  defp deps do
    [
      {:amqp_client, "~> 3.7.11"},
      {:rabbit_common, "~> 3.7.11"},

      # We have an issue on rebar3 dependencies.
      # https://github.com/pma/amqp/issues/78
      {:goldrush, "~> 0.1.0"},
      {:jsx, "~> 2.9"},
      {:lager, "~> 3.6.5"},
      {:ranch, "~> 1.7"},
      {:recon, "~> 2.3"},

      {:earmark, "~> 1.0", only: :docs},
      {:ex_doc, "~> 0.15", only: :docs},
      {:inch_ex, "~> 0.5", only: :docs},

      {:dialyxir, "~> 0.5", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Idiomatic Elixir client for RabbitMQ.
    """
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
     maintainers: ["Paulo Almeida", "Eduardo Gurgel"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/pma/amqp"}]
  end
end
