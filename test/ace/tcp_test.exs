defmodule Ace.TCP.EndpointTest do
  use ExUnit.Case, async: true

  test "echos each message" do
    {:ok, endpoint} = Ace.TCP.start_link({EchoServer, []}, port: 0)
    {:ok, port} = Ace.TCP.port(endpoint)

    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])
    :ok = :gen_tcp.send(client, "blob\r\n")
    assert {:ok, "ECHO: blob\r\n"} = :gen_tcp.recv(client, 0)
  end

  test "says welcome for new connection" do
    {:ok, endpoint} = Ace.TCP.start_link({GreetingServer, "WELCOME"}, port: 0)
    {:ok, port} = Ace.TCP.port(endpoint)

    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])
    assert {:ok, "WELCOME\r\n"} = :gen_tcp.recv(client, 0, 2000)
  end

  test "socket broadcasts server notification" do
    {:ok, endpoint} = Ace.TCP.start_link({BroadcastServer, self()}, port: 0)
    {:ok, port} = Ace.TCP.port(endpoint)

    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])
    receive do
      {:register, pid} ->
        send(pid, {:notify, "HELLO"})
      end
    assert {:ok, "HELLO\r\n"} = :gen_tcp.recv(client, 0)
  end

  test "socket ignores debug messages" do
    {:ok, endpoint} = Ace.TCP.start_link({BroadcastServer, self()}, port: 0)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])
    receive do
      {:register, pid} ->
        send(pid, :debug)
    end
    assert {:error, :timeout} == :gen_tcp.recv(client, 0, 1000)
  end

  test "state is passed through messages" do
    {:ok, endpoint} = Ace.TCP.start_link({CounterServer, 0}, port: 0)
    {:ok, port} = Ace.TCP.port(endpoint)

    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])
    :ok = :gen_tcp.send(client, "INC\r\n")
    # If sending raw packets they can be read as part of the same packet if sent too fast.
    :timer.sleep(100)
    :ok = :gen_tcp.send(client, "INC\r\n")
    :timer.sleep(100)
    :ok = :gen_tcp.send(client, "TOTAL\r\n")
    assert {:ok, "2\r\n"} = :gen_tcp.recv(client, 0, 2000)
  end

  test "start multiple connections" do
    {:ok, endpoint} = Ace.TCP.start_link({CounterServer, 0}, port: 0)
    {:ok, port} = Ace.TCP.port(endpoint)
    {:ok, client1} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])
    {:ok, client2} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])
    :ok = :gen_tcp.send(client1, "TOTAL\r\n")
    assert {:ok, "0\r\n"} = :gen_tcp.recv(client1, 0)
    :ok = :gen_tcp.send(client2, "TOTAL\r\n")
    assert {:ok, "0\r\n"} = :gen_tcp.recv(client2, 0)
  end

  test "will register the new enpoint with the given name" do
    {:ok, endpoint} = Ace.TCP.start_link({EchoServer, []}, port: 0, name: NamedEndpoint)
    assert endpoint == Process.whereis(NamedEndpoint)
  end

  test "there are n servers accepting at any given time" do
    {:ok, endpoint} = Ace.TCP.start_link({EchoServer, []}, port: 0, acceptors: 10)
    {_, _, governor_supervisor} = :sys.get_state(endpoint)
    assert %{active: 10} = Supervisor.count_children(governor_supervisor)
  end

  test "server is initialised with correct peer information" do
    {:ok, endpoint} = Ace.TCP.start_link({Forwarder, self()}, port: 0, acceptors: 2)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])
    {:ok, client_name} = :inet.sockname(client)

    assert_receive {:conn, %{peer: ^client_name}}
  end

  test "can set a timeout in response to new connection" do
    {:ok, endpoint} = Ace.TCP.start_link({Timeout, 10}, port: 0, acceptors: 2)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])

    assert {:ok, "HI\r\n"} = :gen_tcp.recv(client, 0)
    assert {:ok, "TIMEOUT 10\r\n"} = :gen_tcp.recv(client, 0, 1000)
  end

  test "can set a timeout in response to a packet" do
    {:ok, endpoint} = Ace.TCP.start_link({Timeout, 10}, port: 0, acceptors: 2)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])

    {:ok, "HI\r\n"} = :gen_tcp.recv(client, 0, 1000)
    {:ok, "TIMEOUT 10\r\n"} = :gen_tcp.recv(client, 0, 1000)

    :ok = :gen_tcp.send(client, "PING\r\n")
    {:ok, "PONG\r\n"} = :gen_tcp.recv(client, 0, 1000)
    {:ok, "TIMEOUT 10\r\n"} = :gen_tcp.recv(client, 0, 1000)
  end

  test "can set a timeout in response to a packet with no immediate reply" do
    {:ok, endpoint} = Ace.TCP.start_link({Timeout, 10}, port: 0, acceptors: 2)
    {:ok, port} = Ace.TCP.Endpoint.port(endpoint)
    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [{:active, false}, :binary])

    {:ok, "HI\r\n"} = :gen_tcp.recv(client, 0, 1000)
    {:ok, "TIMEOUT 10\r\n"} = :gen_tcp.recv(client, 0, 1000)

    :ok = :gen_tcp.send(client, "OTHER\r\n")
    {:ok, "TIMEOUT 10\r\n"} = :gen_tcp.recv(client, 0, 1000)
  end
end