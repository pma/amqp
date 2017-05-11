defmodule AMQP.Mixfile do
  use Mix.Project

  @version "0.2.2"

  def project do
    [app: :amqp,
     version: @version,
     elixir: "~> 1.0",
     description: description(),
     package: package(),
     source_url: "https://github.com/pma/amqp",
     deps: deps(),
     docs: [extras: ["README.md"], main: "readme",
            source_ref: "v#{@version}",
            source_url: "https://github.com/pma/amqp"]]
  end

  def application do
    [applications: [:logger, :amqp_client]]
  end

  defp deps do
    [
      {:amqp_client, "~> 3.6.8"},
      {:rabbit_common, "~> 3.6.8"},

      {:earmark, "~> 1.0", only: :docs},
      {:ex_doc, "~> 0.15", only: :docs},
      {:inch_ex, "~> 0.5", only: :docs}
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
