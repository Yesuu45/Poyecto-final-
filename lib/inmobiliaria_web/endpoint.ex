defmodule InmobiliariaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :inmobiliaria

  @session_options [
    store: :cookie,
    key: "_inmobiliaria_key",
    signing_salt: "inmobiliaria123"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :inmobiliaria,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug InmobiliariaWeb.Router
end
