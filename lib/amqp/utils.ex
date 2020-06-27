defmodule AMQP.Utils do
  @moduledoc false

  @doc "Converts a keyword list into a rabbit_common compatible type tuple"
  def to_type_tuple(fields) when is_list(fields) do
    Enum.map(fields, &to_type_tuple/1)
  end

  def to_type_tuple(:undefined), do: :undefined

  def to_type_tuple({name, type, value}) do
    # Important to cast an array's internal values
    {^type, value} = cast_field_value({type, value})
    {to_string(name), type, value}
  end

  def to_type_tuple({name, value}) do
    {type, value} = cast_field_value(value)
    to_type_tuple({to_string(name), type, value})
  end

  defp cast_field_value({:array, value}) do
    {:array, Enum.map(value, &cast_field_value/1)}
  end

  defp cast_field_value(tuple = {_type, _value}), do: tuple

  defp cast_field_value(value) when is_boolean(value) do
    {:bool, value}
  end

  defp cast_field_value(value) when is_bitstring(value) or is_atom(value) do
    {:longstr, to_string(value)}
  end

  defp cast_field_value(value) when is_integer(value) do
    {:long, value}
  end

  defp cast_field_value(value) when is_float(value) do
    {:float, value}
  end

  defp cast_field_value(value) when is_list(value) do
    {:array, Enum.map(value, &cast_field_value/1)}
  end
end
