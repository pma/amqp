defmodule AMQP.Core do
  @moduledoc false

  require Record

  Record.defrecord(
    :p_basic,
    :P_basic,
    Record.extract(:P_basic, from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_declare_ok,
    :"queue.declare_ok",
    Record.extract(:"queue.declare_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_bind,
    :"queue.bind",
    Record.extract(:"queue.bind", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_bind_ok,
    :"queue.bind_ok",
    Record.extract(:"queue.bind_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_unbind,
    :"queue.unbind",
    Record.extract(:"queue.unbind", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_unbind_ok,
    :"queue.unbind_ok",
    Record.extract(:"queue.unbind_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_delete,
    :"queue.delete",
    Record.extract(:"queue.delete", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_delete_ok,
    :"queue.delete_ok",
    Record.extract(:"queue.delete_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_purge,
    :"queue.purge",
    Record.extract(:"queue.purge", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_purge_ok,
    :"queue.purge_ok",
    Record.extract(:"queue.purge_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_get,
    :"basic.get",
    Record.extract(:"basic.get", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_get_ok,
    :"basic.get_ok",
    Record.extract(:"basic.get_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_get_empty,
    :"basic.get_empty",
    Record.extract(:"basic.get_empty", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_ack,
    :"basic.ack",
    Record.extract(:"basic.ack", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_consume,
    :"basic.consume",
    Record.extract(:"basic.consume", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_consume_ok,
    :"basic.consume_ok",
    Record.extract(:"basic.consume_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_publish,
    :"basic.publish",
    Record.extract(:"basic.publish", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_return,
    :"basic.return",
    Record.extract(:"basic.return", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_cancel,
    :"basic.cancel",
    Record.extract(:"basic.cancel", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_cancel_ok,
    :"basic.cancel_ok",
    Record.extract(:"basic.cancel_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_deliver,
    :"basic.deliver",
    Record.extract(:"basic.deliver", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_reject,
    :"basic.reject",
    Record.extract(:"basic.reject", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_recover,
    :"basic.recover",
    Record.extract(:"basic.recover", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_recover_ok,
    :"basic.recover_ok",
    Record.extract(:"basic.recover_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :exchange_declare_ok,
    :"exchange.declare_ok",
    Record.extract(:"exchange.declare_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :exchange_delete,
    :"exchange.delete",
    Record.extract(:"exchange.delete", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :exchange_delete_ok,
    :"exchange.delete_ok",
    Record.extract(:"exchange.delete_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :exchange_bind_ok,
    :"exchange.bind_ok",
    Record.extract(:"exchange.bind_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :exchange_unbind,
    :"exchange.unbind",
    Record.extract(:"exchange.unbind", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :exchange_unbind_ok,
    :"exchange.unbind_ok",
    Record.extract(:"exchange.unbind_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_qos,
    :"basic.qos",
    Record.extract(:"basic.qos", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_qos_ok,
    :"basic.qos_ok",
    Record.extract(:"basic.qos_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_nack,
    :"basic.nack",
    Record.extract(:"basic.nack", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :basic_credit_drained,
    :"basic.credit_drained",
    Record.extract(:"basic.credit_drained", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :confirm_select,
    :"confirm.select",
    Record.extract(:"confirm.select", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :confirm_select_ok,
    :"confirm.select_ok",
    Record.extract(:"confirm.select_ok", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :exchange_declare,
    :"exchange.declare",
    Record.extract(:"exchange.declare", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :queue_declare,
    :"queue.declare",
    Record.extract(:"queue.declare", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :exchange_bind,
    :"exchange.bind",
    Record.extract(:"exchange.bind", from_lib: "rabbit_common/include/rabbit_framing.hrl")
  )

  Record.defrecord(
    :amqp_params_network,
    :amqp_params_network,
    Record.extract(:amqp_params_network, from_lib: "amqp_client/include/amqp_client.hrl")
  )

  Record.defrecord(
    :amqp_params_direct,
    :amqp_params_direct,
    Record.extract(:amqp_params_direct, from_lib: "amqp_client/include/amqp_client.hrl")
  )

  Record.defrecord(
    :amqp_adapter_info,
    :amqp_adapter_info,
    Record.extract(:amqp_adapter_info, from_lib: "amqp_client/include/amqp_client.hrl")
  )

  Record.defrecord(
    :amqp_msg,
    :amqp_msg,
    Record.extract(:amqp_msg, from_lib: "amqp_client/include/amqp_client.hrl")
  )
end
