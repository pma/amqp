defmodule Amqp.Mixfile do
  use Mix.Project

  def project do
    [app: :amqp,
     version: "0.0.3",
     elixir: "~> 0.14.3 or ~> 0.15.0",
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.5", only: :docs},
     {:amqp_client, "~> 3.0"}]
  end
end
