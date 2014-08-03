defmodule Amqp.Mixfile do
  use Mix.Project

  def project do
    [app: :amqp,
     version: "0.0.1",
     elixir: "~> 0.14.1 or ~> 0.15.0",
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:ex_doc, github: "elixir-lang/ex_doc", only: :dev},
     {:markdown, github: "devinus/markdown", only: :dev},
     {:amqp_client, github: "pma/amqp_client", tag: "rabbitmq-3.3.4"}]
  end
end
