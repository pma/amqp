defmodule AMQP.Mixfile do
  use Mix.Project

  def project do
    [app: :amqp,
     version: "0.1.1-dev",
     elixir: "~> 1.0.0",
     description: description,
     package: package,
     source_url: "https://github.com/pma/amqp",
     deps: deps,
     docs: [readme: "README.md", main: "README"]]
  end

  def application do
    [applications: [:logger, :xmerl, :amqp_client, :rabbit_common]]
  end

  defp deps do
    [{:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.7", only: :docs},
     {:inch_ex, "~> 0.2", only: :docs},
     {:amqp_client, github: "pma/amqp_client"},
     {:rabbit_common, github: "pma/rabbit_common", override: true}]
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
