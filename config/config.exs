import Config

config :park_bench,
  ecto_repos: [ParkBench.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :park_bench, ParkBenchWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ParkBenchWeb.ErrorHTML, json: ParkBenchWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ParkBench.PubSub,
  live_view: [signing_salt: "LIKl7tn6"]

# Configure esbuild
config :esbuild,
  version: "0.25.4",
  park_bench: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  park_bench_css: [
    args: ~w(css/park_bench.css --bundle --outdir=../priv/static/assets/css --loader:.css=css),
    cd: Path.expand("../assets", __DIR__)
  ]

# Oban configuration
config :park_bench, Oban,
  engine: Oban.Engines.Basic,
  repo: ParkBench.Repo,
  queues: [
    default: 10,
    ai_detection: 20,
    email: 10,
    notifications: 15,
    photos: 10,
    cleanup: 5
  ],
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", ParkBench.Workers.NotificationPruneWorker},
       {"0 3 * * *", ParkBench.Workers.SoftDeleteCleanupWorker},
       {"*/15 * * * *", ParkBench.Workers.SessionPruneWorker},
       {"0 4 * * *", ParkBench.Workers.UnverifiedAccountPurgeWorker}
     ]}
  ]

# Swoosh mailer config
config :park_bench, ParkBench.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client - use Req-based client or disable for local adapter
config :swoosh, :api_client, false

# AI Detection defaults
config :park_bench, :ai_detection,
  text_provider: ParkBench.AIDetection.Clients.GPTZero,
  image_provider: ParkBench.AIDetection.Clients.HiveModeration,
  text_soft_reject: 0.65,
  text_hard_reject: 0.85,
  image_soft_reject: 0.70,
  image_hard_reject: 0.90,
  min_text_length: 50

# Message encryption key (override in runtime.exs for prod)
config :park_bench, :message_encryption_key, "dev-only-key-must-be-32-bytes!!"

# S3 / ExAws config (defaults for dev with MinIO)
config :ex_aws,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin",
  region: "us-east-1"

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 9000

config :park_bench, :s3_bucket, "park-bench-uploads"

# Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Sentry - disable in dev, configure client
config :sentry,
  environment_name: Mix.env(),
  client: Sentry.FinchClient

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
