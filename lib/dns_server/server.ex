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
    {:ok, Map.put(state, :server_socket, socket)}
  end

  @impl true
  def handle_info({:udp, socket, address, port, data}, %{server_socket: socket} = state) do
    Logger.info("Got request from #{inspect address} #{port}")
    message = Message.parse_message(data)
    
        # #Logger.info("Datagram from #{inspect address} #{port}")
    # {:ok, client_socket} = :gen_udp.open(0, [:binary, active: true])

    # if address == {127,0,0,1} do
    #   :gen_udp.send(client_socket, {8,8,8,8}, 53, data)
    # else
    #   require IEx;
    #   IEx.pry
    # end


    # Logger.info(inspect Message.parse_message(data))
    {:noreply, state}
  end

  def handle_request()
end
