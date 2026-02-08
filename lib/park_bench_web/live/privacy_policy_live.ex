defmodule ParkBenchWeb.PrivacyPolicyLive do
  use ParkBenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Privacy Policy")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="static-page">
      <h1>Privacy Policy</h1>
      <p><em>Last updated: February 2026</em></p>

      <h2>Information We Collect</h2>
      <p>
        When you create an account, we collect your name, email address, and password.
        You may optionally provide additional profile information such as your birthday,
        hometown, interests, education, and work history.
      </p>

      <h2>How We Use Your Information</h2>
      <p>
        We use your information to provide the ParkBench social networking service,
        including displaying your profile to other users according to your privacy
        settings, delivering messages, and showing relevant content in your news feed.
      </p>

      <h2>AI Content Detection</h2>
      <p>
        Content posted on ParkBench may be analyzed by third-party AI detection services
        (such as GPTZero and Hive Moderation) to identify AI-generated text and images.
        Detection results are stored and may be reviewed by moderators.
      </p>

      <h2>Your Privacy Controls</h2>
      <p>
        You can control who sees your profile information through your Privacy Settings.
        Each piece of information can be set to visible to everyone, friends only, or only you.
      </p>

      <h2>Data Security</h2>
      <p>
        Private messages are encrypted at rest using AES-256-GCM encryption.
        Passwords are hashed using Argon2. We use HTTPS for all connections.
      </p>

      <h2>Contact</h2>
      <p>
        If you have questions about this privacy policy, please contact us through the site.
      </p>
    </div>
    """
  end
end
