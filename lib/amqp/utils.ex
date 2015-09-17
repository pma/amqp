defmodule AMQP.Utils do
  @moduledoc false

  @doc "Converts a keyword list into a rabbit_common compatible type tuple"
  def to_type_tuple(fields) when is_list(fields) do
    Enum.map fields, &to_type_tuple/1
  end
  def to_type_tuple(:undefined), do: :undefined
  def to_type_tuple({name, type, value}), do: {to_string(name), type, value}
  def to_type_tuple({name, value}) when is_boolean(value) do
    to_type_tuple {name, :bool, value}
  end
  def to_type_tuple({name, value}) when is_bitstring(value) or is_atom(value) do
    to_type_tuple {name, :longstr, to_string(value)}
  end
  def to_type_tuple({name, value}) when is_integer(value) do
    to_type_tuple {name, :long, value}
  end
  def to_type_tuple({name, value}) when is_float(value) do
    to_type_tuple {name, :float, value}
  end
end
