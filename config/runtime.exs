import Config

if System.get_env("PHX_SERVER") do
  config :park_bench, ParkBenchWeb.Endpoint, server: true
end

config :park_bench, ParkBenchWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :park_bench, ParkBench.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "parkbench.app"

  config :park_bench, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :park_bench, ParkBenchWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base

  # Message encryption key (32 bytes, base64 encoded in env)
  message_key =
    System.get_env("MESSAGE_ENCRYPTION_KEY") ||
      raise "environment variable MESSAGE_ENCRYPTION_KEY is missing (32-byte key)"

  config :park_bench, :message_encryption_key, message_key

  # S3 configuration
  config :ex_aws,
    access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
    region: System.get_env("AWS_REGION", "us-east-1")

  config :park_bench, :s3_bucket, System.get_env("S3_BUCKET", "park-bench-uploads")

  # AI Detection API keys
  config :park_bench, :ai_detection,
    gptzero_api_key: System.get_env("GPTZERO_API_KEY"),
    hive_api_key: System.get_env("HIVE_API_KEY")

  # Swoosh / SES email
  config :park_bench, ParkBench.Mailer,
    adapter: Swoosh.Adapters.AmazonSES,
    region: System.get_env("AWS_REGION", "us-east-1"),
    access_key: System.get_env("AWS_ACCESS_KEY_ID"),
    secret: System.get_env("AWS_SECRET_ACCESS_KEY")

  # Sentry
  if dsn = System.get_env("SENTRY_DSN") do
    config :sentry,
      dsn: dsn,
      environment_name: :prod,
      enable_source_code_context: true,
      root_source_code_paths: [File.cwd!()]
  end
end
