defmodule Sunporch.Mailer.Email do
  @moduledoc "Builds transactional emails for the Sunporch application."

  import Swoosh.Email

  @from {"Sunporch", "noreply@sunporch.app"}

  @doc "Builds a verification email with the given token."
  def verification_email(user, token) do
    verification_url = "#{base_url()}/verify-email/#{token}"

    new()
    |> to({user.display_name, user.email})
    |> from(@from)
    |> subject("Verify your Sunporch email address")
    |> html_body("""
    <div style="font-family: 'Lucida Grande', Tahoma, Verdana, Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <div style="background-color: #3b5998; padding: 16px 24px; border-radius: 3px 3px 0 0;">
        <h1 style="color: #ffffff; font-size: 24px; margin: 0; letter-spacing: -1px;">sunporch</h1>
      </div>
      <div style="padding: 24px; border: 1px solid #dddfe2; border-top: none; border-radius: 0 0 3px 3px;">
        <p style="color: #1d2129; font-size: 16px; margin: 0 0 16px 0;">
          Hi #{user.display_name},
        </p>
        <p style="color: #1d2129; font-size: 14px; margin: 0 0 16px 0;">
          Thanks for signing up for Sunporch! Please verify your email address by clicking the button below.
        </p>
        <div style="text-align: center; margin: 24px 0;">
          <a href="#{verification_url}"
             style="background-color: #42b72a; color: #ffffff; padding: 12px 32px; border-radius: 5px; text-decoration: none; font-size: 16px; font-weight: bold; display: inline-block;">
            Verify Email Address
          </a>
        </div>
        <p style="color: #90949c; font-size: 12px; margin: 16px 0 0 0;">
          If you didn't create a Sunporch account, you can safely ignore this email.
          This link will expire in 24 hours.
        </p>
        <p style="color: #90949c; font-size: 12px; margin: 8px 0 0 0;">
          Or copy and paste this link: #{verification_url}
        </p>
      </div>
    </div>
    """)
    |> text_body("""
    Hi #{user.display_name},

    Thanks for signing up for Sunporch! Please verify your email address by visiting the link below:

    #{verification_url}

    If you didn't create a Sunporch account, you can safely ignore this email.
    This link will expire in 24 hours.
    """)
  end

  @doc "Builds a password reset email with the given token."
  def password_reset_email(user, token) do
    reset_url = "#{base_url()}/reset-password/#{token}"

    new()
    |> to({user.display_name, user.email})
    |> from(@from)
    |> subject("Reset your Sunporch password")
    |> html_body("""
    <div style="font-family: 'Lucida Grande', Tahoma, Verdana, Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <div style="background-color: #3b5998; padding: 16px 24px; border-radius: 3px 3px 0 0;">
        <h1 style="color: #ffffff; font-size: 24px; margin: 0; letter-spacing: -1px;">sunporch</h1>
      </div>
      <div style="padding: 24px; border: 1px solid #dddfe2; border-top: none; border-radius: 0 0 3px 3px;">
        <p style="color: #1d2129; font-size: 16px; margin: 0 0 16px 0;">
          Hi #{user.display_name},
        </p>
        <p style="color: #1d2129; font-size: 14px; margin: 0 0 16px 0;">
          We received a request to reset the password for your Sunporch account.
          Click the button below to choose a new password.
        </p>
        <div style="text-align: center; margin: 24px 0;">
          <a href="#{reset_url}"
             style="background-color: #3b5998; color: #ffffff; padding: 12px 32px; border-radius: 5px; text-decoration: none; font-size: 16px; font-weight: bold; display: inline-block;">
            Reset Password
          </a>
        </div>
        <p style="color: #90949c; font-size: 12px; margin: 16px 0 0 0;">
          If you didn't request a password reset, you can safely ignore this email.
          Your password will not be changed. This link will expire in 1 hour.
        </p>
        <p style="color: #90949c; font-size: 12px; margin: 8px 0 0 0;">
          Or copy and paste this link: #{reset_url}
        </p>
      </div>
    </div>
    """)
    |> text_body("""
    Hi #{user.display_name},

    We received a request to reset the password for your Sunporch account.
    Visit the link below to choose a new password:

    #{reset_url}

    If you didn't request a password reset, you can safely ignore this email.
    Your password will not be changed. This link will expire in 1 hour.
    """)
  end

  @doc "Builds a friend request notification email."
  def friend_request_email(user, from_user) do
    profile_url = "#{base_url()}/profile/#{from_user.slug}"

    new()
    |> to({user.display_name, user.email})
    |> from(@from)
    |> subject("#{from_user.display_name} sent you a friend request on Sunporch")
    |> html_body("""
    <div style="font-family: 'Lucida Grande', Tahoma, Verdana, Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <div style="background-color: #3b5998; padding: 16px 24px; border-radius: 3px 3px 0 0;">
        <h1 style="color: #ffffff; font-size: 24px; margin: 0; letter-spacing: -1px;">sunporch</h1>
      </div>
      <div style="padding: 24px; border: 1px solid #dddfe2; border-top: none; border-radius: 0 0 3px 3px;">
        <p style="color: #1d2129; font-size: 16px; margin: 0 0 16px 0;">
          Hi #{user.display_name},
        </p>
        <p style="color: #1d2129; font-size: 14px; margin: 0 0 16px 0;">
          <strong>#{from_user.display_name}</strong> wants to be your friend on Sunporch.
        </p>
        <div style="text-align: center; margin: 24px 0;">
          <a href="#{profile_url}"
             style="background-color: #3b5998; color: #ffffff; padding: 12px 32px; border-radius: 5px; text-decoration: none; font-size: 16px; font-weight: bold; display: inline-block;">
            View Profile
          </a>
        </div>
        <p style="color: #90949c; font-size: 12px; margin: 16px 0 0 0;">
          Log in to Sunporch to accept or decline this friend request.
        </p>
      </div>
    </div>
    """)
    |> text_body("""
    Hi #{user.display_name},

    #{from_user.display_name} wants to be your friend on Sunporch.

    View their profile: #{profile_url}

    Log in to Sunporch to accept or decline this friend request.
    """)
  end

  # Returns the application base URL for building links in emails.
  defp base_url do
    Application.get_env(:sunporch, SunporchWeb.Endpoint)[:url][:host]
    |> case do
      "localhost" ->
        port = Application.get_env(:sunporch, SunporchWeb.Endpoint)[:http][:port] || 4000
        "http://localhost:#{port}"

      host when is_binary(host) ->
        "https://#{host}"

      _ ->
        "http://localhost:4000"
    end
  end
end
