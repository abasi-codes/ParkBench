defmodule SunporchWeb.OnboardingWelcomeLive do
  use SunporchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user.onboarding_completed_at do
      {:ok, push_navigate(socket, to: "/feed")}
    else
      {:ok, assign(socket, :page_title, "Welcome to Sunporch")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="single-column" style="max-width: 600px; margin: 0 auto;">
      <div class="onboarding-progress">
        <div class="onboarding-steps">
          <span class="onboarding-step active">1. Welcome</span>
          <span class="onboarding-step-separator">&rarr;</span>
          <span class="onboarding-step">2. Guidelines</span>
          <span class="onboarding-step-separator">&rarr;</span>
          <span class="onboarding-step">3. Privacy</span>
          <span class="onboarding-step-separator">&rarr;</span>
          <span class="onboarding-step">4. Profile</span>
        </div>
        <div class="onboarding-step-label">Step 1 of 4</div>
      </div>

      <div class="content-box-padded">
        <h1 style="font-size: 18px; font-weight: bold; color: #3b5998; margin-bottom: 12px;">
          Welcome to Sunporch
        </h1>

        <p style="font-size: 14px; line-height: 1.5; margin-bottom: 12px; color: #333;">
          Welcome, {@current_user.display_name}! Sunporch is a social network built for humans.
          We are glad you are here.
        </p>

        <div class="sidebar-box" style="margin-bottom: 12px;">
          <div class="sidebar-box-header">What makes Sunporch different</div>
          <div class="sidebar-box-content">
            <ul style="list-style: none; padding: 0; margin: 0;">
              <li style="padding: 6px 0; border-bottom: 1px solid #f0f0f0; font-size: 11px;">
                <strong>No AI-generated content.</strong>
                Everything here is written by real people. We actively detect and remove
                AI-generated posts, comments, and images.
              </li>
              <li style="padding: 6px 0; border-bottom: 1px solid #f0f0f0; font-size: 11px;">
                <strong>Privacy first.</strong>
                You control exactly who sees your information. No data selling,
                no algorithmic feeds, no ads.
              </li>
              <li style="padding: 6px 0; font-size: 11px;">
                <strong>Real connections.</strong>
                Sunporch is about connecting with people you actually know. Write on
                their wall, poke them, share updates with friends.
              </li>
            </ul>
          </div>
        </div>

        <p style="font-size: 11px; color: #666; margin-bottom: 12px;">
          Let us walk you through a few things to get you set up. It will only take a minute.
        </p>

        <div class="form-actions-right">
          <a href="/onboarding/guidelines" class="btn btn-blue">
            Get Started &rarr;
          </a>
        </div>
      </div>
    </div>
    """
  end
end
