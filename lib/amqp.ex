defmodule AMQP do
  @moduledoc """
  This module provides AMQP-related types.
  """

  @type argument_type() ::
          :longstr
          | :signedint
          | :decimal
          | :timestamp
          | :table
          | :byte
          | :double
          | :float
          | :long
          | :short
          | :bool
          | :binary
          | :void
          | :array

  @type arguments() :: [{String.t(), argument_type(), term()}]

  defmacro __using__(_opts) do
    quote do
      alias AMQP.Connection
      alias AMQP.Channel
      alias AMQP.Exchange
      alias AMQP.Queue
      alias AMQP.Basic
      alias AMQP.Confirm
    end
  end
end
