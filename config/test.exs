import Config

config :park_bench, ParkBench.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "park_bench_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :park_bench, ParkBenchWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "S/Q0DSG2GfrUk1NQ8t1LGQ4qX7ExaUpviA/CRWHtqjOTIOwkGOFJPhTaPfapcy6I",
  server: false

# Disable Oban during tests
config :park_bench, Oban, testing: :manual

# Use test adapters for AI detection
config :park_bench, :ai_detection,
  text_provider: ParkBench.AIDetection.Clients.MockText,
  image_provider: ParkBench.AIDetection.Clients.MockImage

# Test encryption key (exactly 32 bytes)
config :park_bench, :message_encryption_key, "test-key-must-be-exactly-32-by!"

# Swoosh test adapter
config :park_bench, ParkBench.Mailer, adapter: Swoosh.Adapters.Test

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix,
  sort_verified_routes_query_params: true
