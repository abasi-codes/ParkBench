defmodule SunporchWeb.Layouts do
  use SunporchWeb, :html

  embed_templates "layouts/*"

  defp notification_text(type) do
    case type do
      "friend_request" -> "sent you a friend request"
      "friend_accepted" -> "accepted your friend request"
      "wall_post" -> "posted on your wall"
      "comment" -> "commented on your post"
      "like" -> "liked your post"
      "poke" -> "poked you"
      "mention" -> "mentioned you"
      _ -> "sent you a notification"
    end
  end
end
