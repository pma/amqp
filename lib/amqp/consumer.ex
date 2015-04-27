defmodule AMQP.Consumer.Behaviour do
  @moduledoc false
  use Behaviour

  defcallback handle_basic_deliver(payload :: String.t, meta :: Map.t, state :: term) :: {:noreply, new_state :: term} |
                                                                                         {:noreply, new_state :: term, timeout | :hibernate} |
                                                                                         {:stop, reason :: term, new_state :: term}
  defcallback handle_basic_consume_ok(consumer_tag :: String.t, state :: term) :: {:noreply, new_state :: term} |
                                                                                  {:noreply, new_state :: term, timeout | :hibernate} |
                                                                                  {:stop, reason :: term, new_state :: term}
  defcallback handle_basic_cancel_ok(consumer_tag :: String.t, state :: term) :: {:noreply, new_state :: term} |
                                                                                 {:noreply, new_state :: term, timeout | :hibernate} |
                                                                                 {:stop, reason :: term, new_state :: term}
  defcallback handle_basic_cancel(consumer_tag :: String.t, no_wait :: boolean, state :: term) :: {:noreply, new_state :: term} |
                                                                                                  {:noreply, new_state :: term, timeout | :hibernate} |
                                                                                                  {:stop, reason :: term, new_state :: term}
end

defmodule AMQP.Consumer do
  @moduledoc """
  Implements a generic behaviour for consuming messages
  """

  defmacro __using__(_) do
    quote location: :keep do
      use AMQP
      use GenServer
      @behaviour AMQP.Consumer.Behaviour
      import AMQP.Core
      require Record

      Record.defrecordp :amqp_msg, [props: p_basic(), payload: ""]

      @doc false
      def handle_info({basic_deliver(consumer_tag: consumer_tag,
                                     delivery_tag: delivery_tag,
                                     redelivered: redelivered,
                                     exchange: exchange,
                                     routing_key: routing_key),
                       amqp_msg(props: p_basic(content_type: content_type,
                                               content_encoding: content_encoding,
                                               headers: headers,
                                               delivery_mode: delivery_mode,
                                               priority: priority,
                                               correlation_id: correlation_id,
                                               reply_to: reply_to,
                                               expiration: expiration,
                                               message_id: message_id,
                                               timestamp: timestamp,
                                               type: type,
                                               user_id: user_id,
                                               app_id: app_id,
                                               cluster_id: cluster_id), payload: payload)}, state) do
        handle_basic_deliver(payload, %{consumer_tag: consumer_tag,
                                        delivery_tag: delivery_tag,
                                        redelivered: redelivered,
                                        exchange: exchange,
                                        routing_key: routing_key,
                                        content_type: content_type,
                                        content_encoding: content_encoding,
                                        headers: headers,
                                        persistent: delivery_mode == 2,
                                        priority: priority,
                                        correlation_id: correlation_id,
                                        reply_to: reply_to,
                                        expiration: expiration,
                                        message_id: message_id,
                                        timestamp: timestamp,
                                        type: type,
                                        user_id: user_id,
                                        app_id: app_id,
                                        cluster_id: cluster_id}, state)
      end

      @doc false
      def handle_info(basic_consume_ok(consumer_tag: consumer_tag), state) do
        handle_basic_consume_ok(consumer_tag, state)
      end

      @doc false
      def handle_info(basic_cancel_ok(consumer_tag: consumer_tag), state) do
        handle_basic_cancel_ok(consumer_tag, state)
      end

      @doc false
      def handle_info(basic_cancel(consumer_tag: consumer_tag, nowait: no_wait), state) do
        handle_basic_cancel(consumer_tag, no_wait, state)
      end

      @doc false
      def handle_basic_consume_ok(consumer_tag, state) do
        {:noreply, state}
      end

      @doc false
      def handle_basic_cancel_ok(consumer_tag, state) do
        {:stop, :normal, state}
      end

      @doc false
      def handle_basic_cancel(consumer_tag, no_wait, state) do
        {:stop, :normal, state}
      end

      @doc false
      def handle_basic_deliver(payload, meta, state) do
        # We do this to trick dialyzer to not complain about non-local returns.
        case :random.uniform(1) do
          1 -> exit({:bad_call, :basic_deliver})
          2 -> {:noreply, state}
        end
      end

      defoverridable [handle_basic_consume_ok: 2,
                      handle_basic_cancel_ok: 2,
                      handle_basic_cancel: 3,
                      handle_basic_deliver: 3]

    end
  end
end
