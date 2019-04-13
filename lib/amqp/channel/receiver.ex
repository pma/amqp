defmodule AMQP.Channel.Receiver do
  @moduledoc false

  def handle_message(chan_pid, client_pid) do
    receive do
      msg ->
        IO.inspect(msg)
        handle_message(chan_pid, client_pid)
    end
  end
end
