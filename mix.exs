defmodule Amqp.Mixfile do
  use Mix.Project

  def project do
    [app: :amqp,
     version: "0.0.2",
     elixir: "~> 0.14.3 or ~> 0.15.0",
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.5", only: :dev},
     {:amqp_client, github: "pma/amqp_client", tag: "rabbitmq-3.3.5"}]
  end
end
