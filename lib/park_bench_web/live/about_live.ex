defmodule ParkBenchWeb.AboutLive do
  use ParkBenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "About")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="static-page">
      <h1>About ParkBench</h1>
      <p>
        ParkBench is a social network designed to connect you with friends and family.
        Share what's on your mind, post on your friends' walls, and stay in touch
        with the people who matter most.
      </p>
      <h2>Our Mission</h2>
      <p>
        We believe in bringing people together through simple, authentic communication.
        ParkBench provides a clean, distraction-free space to keep up with your social circle.
      </p>
      <h2>Features</h2>
      <ul>
        <li>Post on your wall and your friends' walls</li>
        <li>Send private messages to friends</li>
        <li>Poke your friends to say hello</li>
        <li>Customize your profile with photos and personal info</li>
        <li>Control your privacy with granular settings</li>
      </ul>
      <h2>AI Content Policy</h2>
      <p>
        ParkBench uses AI detection tools to help identify AI-generated content.
        We believe in authentic human expression and encourage users to share
        their own thoughts and creations.
      </p>
    </div>
    """
  end
end
