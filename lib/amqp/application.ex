defmodule AMQP.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      worker(AMQP.Channel.ReceiverManager, [])
    ]

    opts = [strategy: :one_for_one, name: AMQP.Application]
    Supervisor.start_link(children, opts)
  end
end
