defmodule AMQP.Mixfile do
  use Mix.Project

  @version "0.1.3"

  def project do
    [app: :amqp,
     version: @version,
     elixir: "~> 1.0",
     description: description,
     package: package,
     source_url: "https://github.com/pma/amqp",
     deps: deps,
     docs: [extras: ["README.md"], main: "README",
            source_ref: "v#{@version}",
            source_url: "https://github.com/pma/amqp"]]
  end

  def application do
    [applications: [:logger, :amqp_client]]
  end

  defp deps do
    [{:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.9", only: :docs},
     {:inch_ex, "~> 0.4", only: :docs},
     {:amqp_client, "~> 3.5.0"}]
  end

  defp description do
    """
    Idiomatic Elixir client for RabbitMQ.
    """
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
     contributors: ["Paulo Almeida", "Eduardo Gurgel"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/pma/amqp"}]
  end
end
