import Config

config :sunporch, Sunporch.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sunporch_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :sunporch, SunporchWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "S/Q0DSG2GfrUk1NQ8t1LGQ4qX7ExaUpviA/CRWHtqjOTIOwkGOFJPhTaPfapcy6I",
  server: false

# Disable Oban during tests
config :sunporch, Oban, testing: :manual

# Use test adapters for AI detection
config :sunporch, :ai_detection,
  text_provider: Sunporch.AIDetection.Clients.MockText,
  image_provider: Sunporch.AIDetection.Clients.MockImage

# Test encryption key (exactly 32 bytes)
config :sunporch, :message_encryption_key, "test-key-must-be-exactly-32-by!"

# Swoosh test adapter
config :sunporch, Sunporch.Mailer, adapter: Swoosh.Adapters.Test

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix,
  sort_verified_routes_query_params: true
