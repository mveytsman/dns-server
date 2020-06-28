defmodule DnsServer.Server do
  use GenServer

  alias DnsServer.Message

  require Logger

  # Client

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(opts[:name], %{}, opts)
  end

  # Callbacks

  @impl true
  def init(state) do
    {:ok, socket} = :gen_udp.open(5353, [:binary, active: true])
    {:ok, Map.put(state, :socket, socket)}
  end

  @impl true
  def handle_info({:udp, _socket, _address, _port, data}, state) do
    Logger.info(inspect Message.parse_message(data))
    {:noreply, state}
  end
end
