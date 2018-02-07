defmodule AMQP.BasicError do
  @moduledoc """
  Raised when the connection is closed or blocked.
  """
  defexception [:message, :reason]

  def exception(reason: reason) do
    message = "Command failed. Reason: connection #{inspect(reason)}"
    %__MODULE__{message: message, reason: reason}
  end
end
