import Config

config :inmobiliaria, InmobiliariaWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  adapter: Bandit.PhoenixAdapter,
  check_origin: false,
  secret_key_base: "unaclavemuylargadealmenossesentayochocaracteresaqui1234567890abcdef",
  render_errors: [formats: [html: InmobiliariaWeb.ErrorHTML]],
  pubsub_server: Inmobiliaria.PubSub,
  live_view: [signing_salt: "uq_inmobiliaria"]

config :phoenix, :json_library, Jason
