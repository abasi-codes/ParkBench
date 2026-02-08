import Config

config :sunporch, Sunporch.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sunporch_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :sunporch, SunporchWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "O+Mxbdw/wMZVNelcbim60uCkULFEKtv476ZPkU03JUvWLUSLqjuNGCpskeHgNSHX",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:sunporch, ~w(--sourcemap=inline --watch)]},
    esbuild_css: {Esbuild, :install_and_run, [:sunporch_css, ~w(--watch)]}
  ]

config :sunporch, SunporchWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
      ~r"priv/gettext/.*\.po$"E,
      ~r"lib/sunporch_web/router\.ex$"E,
      ~r"lib/sunporch_web/(controllers|live|components)/.*\.(ex|heex)$"E
    ]
  ]

config :sunporch, dev_routes: true

# Disable Oban in dev to avoid cron noise (enable manually if needed)
config :sunporch, Oban, testing: :manual

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
