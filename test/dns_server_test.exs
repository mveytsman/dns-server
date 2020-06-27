defmodule DnsServerTest do
  use ExUnit.Case
  doctest DnsServer

  test "greets the world" do
    assert DnsServer.hello() == :world
  end
end
