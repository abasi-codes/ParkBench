defmodule SunporchWeb.Presence do
  use Phoenix.Presence, otp_app: :sunporch, pubsub_server: Sunporch.PubSub
end
