defmodule SunporchWeb.Router do
  use SunporchWeb, :router

  # Plugs are referenced directly as module plugs, not imported

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SunporchWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug SunporchWeb.Plugs.ContentSecurityPolicy
    plug SunporchWeb.Plugs.LoadCurrentUser
  end

  pipeline :require_auth do
    plug SunporchWeb.Plugs.RequireAuth
  end

  pipeline :require_verified do
    plug SunporchWeb.Plugs.RequireVerifiedEmail
  end

  pipeline :require_admin do
    plug SunporchWeb.Plugs.RequireAdmin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :rate_limit_login do
    plug SunporchWeb.Plugs.RateLimiter, action: :login, limit: 10, window: 900_000
  end

  pipeline :rate_limit_register do
    plug SunporchWeb.Plugs.RateLimiter, action: :register, limit: 3, window: 3_600_000
  end

  pipeline :rate_limit_forgot_password do
    plug SunporchWeb.Plugs.RateLimiter, action: :forgot_password, limit: 5, window: 3_600_000
  end

  # Public routes (no auth)
  scope "/", SunporchWeb do
    pipe_through :browser

    get "/", AuthController, :home
    post "/guest-login", AuthController, :guest_login
    post "/logout", AuthController, :logout
    get "/verify-email/:token", AuthController, :verify_email
    get "/reset-password/:token", AuthController, :show_reset_password
  end

  # Rate-limited public routes
  scope "/", SunporchWeb do
    pipe_through [:browser, :rate_limit_login]
    post "/login", AuthController, :login
  end

  scope "/", SunporchWeb do
    pipe_through [:browser, :rate_limit_register]
    post "/register", AuthController, :register
  end

  scope "/", SunporchWeb do
    pipe_through [:browser, :rate_limit_forgot_password]
    post "/forgot-password", AuthController, :forgot_password
    post "/reset-password/:token", AuthController, :reset_password
  end

  # Onboarding routes (auth required, no email verification required)
  scope "/", SunporchWeb do
    pipe_through [:browser, :require_auth]

    live_session :onboarding,
      layout: {SunporchWeb.Layouts, :app},
      on_mount: [{SunporchWeb.LiveAuth, :ensure_authenticated}] do
      live "/onboarding/welcome", OnboardingWelcomeLive, :index
      live "/onboarding/guidelines", OnboardingGuidelinesLive, :index
      live "/onboarding/privacy", OnboardingPrivacyLive, :index
      live "/onboarding/profile-setup", OnboardingProfileSetupLive, :index
    end
  end

  # Authenticated routes
  scope "/", SunporchWeb do
    pipe_through [:browser, :require_auth, :require_verified]

    live_session :authenticated,
      layout: {SunporchWeb.Layouts, :app},
      on_mount: [{SunporchWeb.LiveAuth, :ensure_authenticated}] do
      live "/feed", FeedLive, :index
      live "/albums/new", AlbumLive, :new
      live "/albums/:id", AlbumLive, :show
      live "/profile/:slug", ProfileLive, :wall
      live "/profile/:slug/info", ProfileLive, :info
      live "/profile/:slug/photos", ProfileLive, :photos
      live "/profile/:slug/friends", FriendsListLive, :index
      live "/friends/requests", FriendRequestsLive, :index
      live "/search", SearchLive, :index
      live "/inbox", InboxLive, :index
      live "/inbox/compose", ComposeMessageLive, :index
      live "/inbox/thread/:id", ThreadLive, :index
      live "/notifications", NotificationsLive, :index
      live "/settings/privacy", SettingsPrivacyLive, :index
      live "/settings/account", SettingsAccountLive, :index
      live "/settings/profile", SettingsProfileLive, :index
      live "/about", AboutLive, :index
      live "/privacy-policy", PrivacyPolicyLive, :index
      live "/terms", TermsLive, :index
    end
  end

  # Admin routes
  scope "/admin", SunporchWeb.Admin do
    pipe_through [:browser, :require_auth, :require_admin]

    live_session :admin,
      layout: {SunporchWeb.Layouts, :app},
      on_mount: [{SunporchWeb.LiveAuth, :ensure_admin}] do
      live "/", DashboardLive, :index
      live "/users", UsersLive, :index
      live "/moderation", ModerationLive, :index
      live "/appeals", AppealsLive, :index
      live "/ai-thresholds", AIThresholdsLive, :index
    end
  end
end
