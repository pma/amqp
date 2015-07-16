defmodule UtilsTest do
  use ExUnit.Case

  alias AMQP.Utils

  test "leaves correct lists as is" do
    type_tuple = {"test", :longstr, "me"}

    assert Utils.to_type_tuple(type_tuple) == type_tuple
  end

  test "converts known datatypes correctly" do
    assert Utils.to_type_tuple([test: "me"]) == [{"test", :longstr, "me"}]
    assert Utils.to_type_tuple([test: true]) == [{"test", :bool, true}]
    assert Utils.to_type_tuple([test: 1]) == [{"test", :long, 1}]
    assert Utils.to_type_tuple([test: 1.0]) == [{"test", :float, 1.0}]
    assert Utils.to_type_tuple([test: :me]) == [{"test", :longstr, "me"}]
  end
end
