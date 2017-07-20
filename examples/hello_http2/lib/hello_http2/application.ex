defmodule HelloHTTP2.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do

    certfile = Application.app_dir(:hello_http2, "/priv/cert.pem")
    keyfile = Application.app_dir(:hello_http2, "/priv/key.pem")

    Ace.HTTP2.start_link(
      {HelloHTTP2.WWW, :conf},
      8443,
      certfile: certfile,
      keyfile: keyfile,
      connections: 3
    )
  end
end