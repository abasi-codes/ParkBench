defmodule SunporchWeb.TermsLive do
  use SunporchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Terms of Service")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="static-page">
      <h1>Terms of Service</h1>
      <p><em>Last updated: February 2026</em></p>

      <h2>Acceptance of Terms</h2>
      <p>
        By creating an account or using Sunporch, you agree to these Terms of Service.
        If you do not agree, please do not use the service.
      </p>

      <h2>User Accounts</h2>
      <p>
        You must provide accurate information when creating your account.
        You are responsible for maintaining the security of your password
        and for all activities under your account.
      </p>

      <h2>Content Policy</h2>
      <p>
        You retain ownership of content you post on Sunporch. By posting,
        you grant Sunporch a license to display your content to other users
        according to your privacy settings.
      </p>

      <h2>AI-Generated Content</h2>
      <p>
        Sunporch encourages authentic human expression. Content identified as
        AI-generated may be flagged, held for review, or removed. Users who
        repeatedly post AI-generated content may have their accounts flagged.
        You may appeal content moderation decisions.
      </p>

      <h2>Prohibited Conduct</h2>
      <ul>
        <li>Harassment, bullying, or threatening other users</li>
        <li>Posting illegal, obscene, or harmful content</li>
        <li>Impersonating other users or public figures</li>
        <li>Attempting to circumvent AI detection systems</li>
        <li>Automated or bot activity without permission</li>
      </ul>

      <h2>Termination</h2>
      <p>
        We may suspend or terminate accounts that violate these terms.
        You may delete your account at any time through your Account Settings.
      </p>
    </div>
    """
  end
end
