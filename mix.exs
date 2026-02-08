defmodule ParkBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :park_bench,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [plt_add_apps: [:mix, :ex_unit]]
    ]
  end

  def application do
    [
      mod: {ParkBench.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core Phoenix
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1.0"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:gettext, "~> 1.0"},

      # Auth & Security
      {:argon2_elixir, "~> 4.0"},
      {:plug_crypto, "~> 2.0"},
      {:html_sanitize_ex, "~> 1.4"},

      # Background Jobs
      {:oban, "~> 2.18"},

      # HTTP Client
      {:req, "~> 0.5"},

      # S3 Storage
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:sweet_xml, "~> 0.7"},

      # Email
      {:swoosh, "~> 1.16"},
      {:gen_smtp, "~> 1.2"},

      # Image Processing
      {:image, "~> 0.54"},

      # Pagination & Slugs
      {:scrivener_ecto, "~> 3.0"},
      {:slugify, "~> 1.3"},

      # Monitoring & Telemetry
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:sentry, "~> 10.0"},

      # Assets
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},

      # Dev & Test
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild park_bench", "esbuild park_bench_css"],
      "assets.deploy": [
        "esbuild park_bench --minify",
        "esbuild park_bench_css --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
