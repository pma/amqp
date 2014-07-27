defmodule AMQP do
  defmacro __using__(_opts) do
    quote do
      alias AMQP.Connection
      alias AMQP.Channel
      alias AMQP.Exchange
      alias AMQP.Queue
      alias AMQP.Basic
    end
  end
end
