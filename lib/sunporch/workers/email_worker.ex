defmodule Sunporch.Workers.EmailWorker do
  @moduledoc "Oban worker for async email delivery via Swoosh"
  use Oban.Worker, queue: :email, max_attempts: 5

  alias Sunporch.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => type} = args}) do
    email = build_email(type, args)

    case Mailer.deliver(email) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_email("verification", %{"user_email" => email, "user_name" => name, "token" => token}) do
    Sunporch.Mailer.Email.verification_email(%{email: email, display_name: name}, token)
  end

  defp build_email("password_reset", %{"user_email" => email, "user_name" => name, "token" => token}) do
    Sunporch.Mailer.Email.password_reset_email(%{email: email, display_name: name}, token)
  end

  defp build_email("friend_request", %{"user_email" => email, "user_name" => name, "from_name" => from_name}) do
    Sunporch.Mailer.Email.friend_request_email(%{email: email, display_name: name}, %{display_name: from_name})
  end
end
