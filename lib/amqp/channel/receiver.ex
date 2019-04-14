defmodule AMQP.Channel.Receiver do
  @moduledoc false

  import AMQP.Core
  alias AMQP.Channel.ReceiverManager

  @doc """
  Handles channel messages.
  """
  @spec handle_message(pid(), pid()) :: no_return
  def handle_message(chan_pid, client_pid) do
    receive do
      {:DOWN, _ref, :process, _pid, reason} ->
        ReceiverManager.unregister_receiver(chan_pid, client_pid)
        exit(reason)

      {:EXIT, _ref, reason} ->
        ReceiverManager.unregister_receiver(chan_pid, client_pid)
        exit(reason)

      msg ->
        do_handle_message(client_pid, msg)
        handle_message(chan_pid, client_pid)
    end
  end

  # -- :amqp_channel.register_confirm_handler

  defp do_handle_message(client_pid,
    basic_ack(delivery_tag: delivery_tag, multiple: multiple))
  do
    send(client_pid, {:basic_ack, delivery_tag, multiple})
  end

  defp do_handle_message(client_pid,
    basic_nack(delivery_tag: delivery_tag, multiple: multiple))
  do
    send(client_pid, {:basic_nack, delivery_tag, multiple})
  end
end
