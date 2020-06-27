defmodule DnsServer.Server do
  use GenServer

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

  @imple true
  def handle_info({:udp, _socket, _address, _port, data}, state) do
    Logger.info(data)
    {:noreply, state}
  end

end
