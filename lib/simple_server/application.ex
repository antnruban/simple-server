defmodule SimpleServer.Application do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [fetch_ip(), fetch_ports()], [])
  end

  def init([ip, ports]) do
    case subscribe([ip, ports]) do
      {:ok, listen_socket, port} ->
        debug_config(ip, port)
        {:ok, socket} = :gen_tcp.accept(listen_socket)
        {:ok, %{ip: ip, port: port, socket: socket}}

      {:error, :no_available_port} ->
        {:stop, :no_available_port_found}

      _ ->
        {:error, {:unknown_reason, self()}}
    end
  end

  def handle_info({:tcp, socket, packet}, state) do
    IO.inspect(packet, label: "incoming packet")
    IO.inspect(state, label: "State")
    :gen_tcp.send(socket, "Hi!\n")
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    IO.inspect("Socket has been closed")
    {:noreply, state}
  end

  def handle_info({:tcp_error, socket, reason}, state) do
    IO.inspect(socket, label: "connection closed due to #{reason}")
    {:noreply, state}
  end

  defp debug_config(ip, port) do
    IO.inspect("IP: #{Enum.join(Tuple.to_list(ip), ".")}")
    IO.inspect("PORT: #{port}")
  end

  defp fetch_ip do
    {:ok, list} = :inet.getif()
    {ip, _broadcast, _netmask} = hd(list)
    ip
  end

  defp fetch_ports do
    Application.get_env(:simple_server, :ports, [8000])
  end

  defp subscribe([_ip, []]) do
    {:error, :no_available_port}
  end

  defp subscribe([ip, ports]) do
    [port | tail] = ports

    case :gen_tcp.listen(port, [:binary, {:packet, 0}, {:active, true}, {:ip, ip}]) do
      {:ok, listen_socket} -> {:ok, listen_socket, port}
      {:error, :eaddrinuse} -> subscribe([ip, tail])
      _ -> {:error, :no_available_port}
    end
  end
end
