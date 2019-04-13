defmodule AMQP.Channel.Receiver do
  @moduledoc false

  alias AMQP.Channel.ReceiverManager

  def handle_message(chan_pid, client_pid) do
    receive do
      {:DOWN, _ref, :process, _pid, reason} ->
        ReceiverManager.unregister_receiver(chan_pid, client_pid)
        IO.inspect(reason)
        exit(reason)

      {:EXIT, _ref, reason} ->
        ReceiverManager.unregister_receiver(chan_pid, client_pid)
        IO.inspect(reason)
        exit(reason)

      msg ->
        IO.inspect(msg)
        handle_message(chan_pid, client_pid)
    end
  end
end
