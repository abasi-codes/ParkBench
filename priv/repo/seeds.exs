# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias ParkBench.Repo
alias ParkBench.Accounts
alias ParkBench.Accounts.{User, UserProfile}
alias ParkBench.Social
alias ParkBench.Timeline
alias ParkBench.Messaging
alias ParkBench.Notifications.Notification
alias ParkBench.Privacy.PrivacySetting
import Ecto.Query

IO.puts("Seeding ParkBench database...")

# Create 10 test users
users =
  for i <- 1..10 do
    {:ok, user} =
      Accounts.register_user(%{
        "email" => "user#{i}@example.com",
        "display_name" =>
          Enum.at(
            [
              "Alice Johnson",
              "Bob Smith",
              "Carol Davis",
              "David Wilson",
              "Eve Martinez",
              "Frank Brown",
              "Grace Lee",
              "Henry Taylor",
              "Ivy Anderson",
              "Jack Thomas"
            ],
            i - 1
          ),
        "password" => "password123!",
        "password_confirmation" => "password123!"
      })

    # Verify email
    user
    |> User.verify_email_changeset()
    |> Repo.update!()

    # Complete onboarding
    user
    |> User.onboarding_changeset()
    |> Repo.update!()

    # Create profile
    Repo.insert!(%UserProfile{
      user_id: user.id,
      bio:
        Enum.at(
          [
            "Hello! I love authentic human connections.",
            "Software engineer by day, musician by night.",
            "Bookworm and coffee addict. Always up for a good conversation.",
            "Outdoor enthusiast. If I'm not at my desk, I'm on a trail.",
            "Foodie, traveler, and amateur photographer.",
            "Just here to connect with real people.",
            "Teacher, learner, and lifelong reader.",
            "Sports fan and weekend warrior.",
            "Creative soul with a passion for art and design.",
            "Dog parent, pizza lover, and trivia champion."
          ],
          i - 1
        ),
      interests:
        Enum.at(
          [
            "reading, hiking, photography",
            "coding, guitar, board games",
            "cooking, travel, yoga",
            "cycling, camping, woodworking",
            "baking, languages, vintage films",
            "fishing, grilling, football",
            "painting, pottery, volunteering",
            "running, basketball, podcasts",
            "drawing, music production, gardening",
            "gaming, astronomy, trivia"
          ],
          i - 1
        ),
      hometown:
        Enum.at(
          [
            "New York, NY",
            "Los Angeles, CA",
            "Chicago, IL",
            "Houston, TX",
            "Phoenix, AZ",
            "Philadelphia, PA",
            "San Antonio, TX",
            "San Diego, CA",
            "Dallas, TX",
            "Austin, TX"
          ],
          i - 1
        ),
      current_city:
        Enum.at(
          [
            "San Francisco, CA",
            "Seattle, WA",
            "Boston, MA",
            "Denver, CO",
            "Portland, OR",
            "Nashville, TN",
            "Minneapolis, MN",
            "Atlanta, GA",
            "Raleigh, NC",
            "Salt Lake City, UT"
          ],
          i - 1
        ),
      birthday: Date.new!(1990 + rem(i, 10), rem(i, 12) + 1, rem(i * 3, 28) + 1),
      gender: if(rem(i, 2) == 0, do: "Male", else: "Female"),
      relationship_status:
        Enum.at(
          [
            "Single",
            "In a Relationship",
            "Married",
            "Single",
            "It's Complicated",
            "In a Relationship",
            "Single",
            "Married",
            "Single",
            "In a Relationship"
          ],
          i - 1
        )
    })

    IO.puts("  Created user: #{user.email}")
    Repo.get!(User, user.id)
  end

# Create an admin user
{:ok, admin} =
  Accounts.register_user(%{
    "email" => "admin@parkbench.app",
    "display_name" => "Admin User",
    "password" => "admin123!admin",
    "password_confirmation" => "admin123!admin"
  })

admin
|> User.verify_email_changeset()
|> Repo.update!()

admin
|> User.admin_changeset(%{role: "admin"})
|> Repo.update!()

Repo.insert!(%UserProfile{user_id: admin.id, bio: "ParkBench administrator"})
IO.puts("  Created admin: admin@parkbench.app")

# ── Privacy Settings ──────────────────────────────────────────────
# Varied settings: user3 (Carol) has friends-only profile, user7 (Grace) has only_me on some fields
for {user, i} <- Enum.with_index(users, 1) do
  settings =
    cond do
      # Carol: friends-only profile
      i == 3 ->
        %PrivacySetting{
          user_id: user.id,
          profile_visibility: "friends",
          friend_list_visibility: "friends",
          wall_posting: "friends"
        }

      # Grace: only_me on several fields
      i == 7 ->
        %PrivacySetting{
          user_id: user.id,
          profile_visibility: "everyone",
          friend_list_visibility: "only_me",
          birthday_visibility: "only_me",
          relationship_visibility: "only_me",
          wall_posting: "friends"
        }

      # Eve: friends-only friend list
      i == 5 ->
        %PrivacySetting{
          user_id: user.id,
          profile_visibility: "everyone",
          friend_list_visibility: "friends",
          wall_posting: "everyone"
        }

      true ->
        %PrivacySetting{user_id: user.id}
    end

  Repo.insert!(settings)
end

Repo.insert!(%PrivacySetting{user_id: admin.id})
IO.puts("  Created privacy settings (varied)")

# ── Friendships ───────────────────────────────────────────────────
friendship_pairs = [
  {0, 1},
  {0, 2},
  {0, 3},
  {0, 4},
  {1, 2},
  {1, 3},
  {1, 5},
  {2, 3},
  {2, 4},
  {2, 6},
  {3, 4},
  {3, 5},
  {3, 7},
  {4, 5},
  {4, 8},
  {5, 6},
  {5, 9},
  {6, 7},
  {7, 8},
  {8, 9},
  {0, 9}
]

for {i, j} <- friendship_pairs do
  user_a = Enum.at(users, i)
  user_b = Enum.at(users, j)

  {low_id, high_id} =
    if user_a.id < user_b.id, do: {user_a.id, user_b.id}, else: {user_b.id, user_a.id}

  Repo.insert!(%ParkBench.Social.Friendship{
    user_id: low_id,
    friend_id: high_id
  })
end

## Admin friendships — make admin friends with Alice, Bob, Carol, David, Eve
for i <- [0, 1, 2, 3, 4] do
  other = Enum.at(users, i)
  {low_id, high_id} = if admin.id < other.id, do: {admin.id, other.id}, else: {other.id, admin.id}

  Repo.insert!(%ParkBench.Social.Friendship{
    user_id: low_id,
    friend_id: high_id
  })
end

IO.puts("  Created #{length(friendship_pairs) + 5} friendships")

# ── Wall Posts ────────────────────────────────────────────────────
post_texts = [
  "Just joined ParkBench! Excited to connect with real people.",
  "Beautiful day outside. Who wants to go for a hike this weekend?",
  "Just finished reading an amazing book. Highly recommend 'The Midnight Library'!",
  "Cooking experiment tonight — wish me luck!",
  "Happy Friday everyone! Any plans for the weekend?",
  "Throwback to that amazing trip last summer. Good times!",
  "New semester, new goals. Let's make this one count.",
  "Just adopted a puppy! Meet Max. He's already the boss of the house.",
  "Coffee and a good book — my idea of a perfect morning.",
  "Grateful for all the wonderful people in my life."
]

wall_posts =
  for i <- 0..9 do
    author = Enum.at(users, i)

    {:ok, post} =
      Timeline.create_wall_post(%{
        author_id: author.id,
        wall_owner_id: author.id,
        body: Enum.at(post_texts, i)
      })

    post
  end

# Some cross-wall posts (friends posting on friends' walls)
cross_wall_posts = [
  {1, 0, "Hey Alice! Great to see you on here."},
  {2, 0, "Alice, we should catch up soon!"},
  {3, 1, "Bob, loved your presentation today."},
  {4, 2, "Carol, that book recommendation was spot on!"},
  {5, 3, "David, are we still on for basketball this weekend?"}
]

extra_posts =
  for {author_idx, wall_idx, body} <- cross_wall_posts do
    author = Enum.at(users, author_idx)
    wall_owner = Enum.at(users, wall_idx)

    {:ok, post} =
      Timeline.create_wall_post(%{
        author_id: author.id,
        wall_owner_id: wall_owner.id,
        body: body
      })

    post
  end

all_posts = wall_posts ++ extra_posts
IO.puts("  Created #{length(all_posts)} wall posts")

# Set varied AI detection statuses on posts
# ~60% approved, ~25% pending, ~15% soft_rejected
ai_statuses = [
  "approved",
  "approved",
  "approved",
  "approved",
  "approved",
  "approved",
  "pending",
  "pending",
  "soft_rejected",
  "soft_rejected"
]

for {post, i} <- Enum.with_index(all_posts) do
  status = Enum.at(ai_statuses, rem(i, length(ai_statuses)))

  Repo.update_all(
    from(p in "wall_posts", where: p.id == type(^post.id, Ecto.UUID)),
    set: [ai_detection_status: status]
  )
end

IO.puts("  Set AI detection statuses on wall posts")

# ── Comments ──────────────────────────────────────────────────────
comment_texts = [
  "Love this!",
  "So true!",
  "Great post!",
  "Couldn't agree more.",
  "Haha, this is awesome!",
  "Thanks for sharing!",
  "Welcome to ParkBench!",
  "I've been meaning to try that.",
  "Count me in!",
  "That's incredible!",
  "Miss you!",
  "So jealous!",
  "We should definitely do this again.",
  "You're the best!",
  "This made my day.",
  "Can't wait!",
  "LOL, classic!",
  "Wow, really?",
  "That's so cool.",
  "Congrats!"
]

comment_count = 0

for post <- Enum.take(all_posts, 10) do
  # 3-7 comments per post
  num_comments = Enum.random(3..7)

  for j <- 1..num_comments do
    # Pick a random user that isn't the post author
    commenter_idx = rem(j + :erlang.phash2(post.id), 10)
    commenter = Enum.at(users, commenter_idx)

    {:ok, _comment} =
      Timeline.create_comment(%{
        author_id: commenter.id,
        commentable_type: "WallPost",
        commentable_id: post.id,
        body: Enum.at(comment_texts, rem(j + :erlang.phash2(post.id, 20), 20))
      })
  end
end

IO.puts("  Created comments on wall posts")

# Set varied AI detection statuses on comments
comment_statuses = [
  "approved",
  "approved",
  "approved",
  "approved",
  "approved",
  "approved",
  "approved",
  "pending",
  "pending",
  "soft_rejected"
]

all_comment_ids = Repo.all(from(c in "comments", select: c.id))

for {comment_id, i} <- Enum.with_index(all_comment_ids) do
  status = Enum.at(comment_statuses, rem(i, length(comment_statuses)))

  Repo.update_all(
    from(c in "comments", where: c.id == type(^comment_id, Ecto.UUID)),
    set: [ai_detection_status: status]
  )
end

IO.puts("  Set AI detection statuses on comments")

# ── Status Updates ────────────────────────────────────────────────
status_texts = [
  "feeling grateful today",
  "working on a fun project",
  "enjoying the sunshine",
  "reading a great book",
  "cooking dinner for friends",
  "excited about the weekend",
  "binge-watching a new show",
  "can't stop thinking about pizza",
  "just got back from the gym",
  "ready for an adventure"
]

for i <- 0..9 do
  user = Enum.at(users, i)
  {:ok, _} = Timeline.create_status_update(%{user_id: user.id, body: Enum.at(status_texts, i)})
end

IO.puts("  Created status updates")

# ── Likes ─────────────────────────────────────────────────────────
like_pairs = [
  # Alice's post gets lots of likes
  {1, 0},
  {2, 0},
  {3, 0},
  {4, 0},
  {5, 0},
  # Bob's post
  {0, 1},
  {2, 1},
  # Carol's post
  {0, 2},
  {1, 2},
  {3, 2},
  # David's post
  {0, 3},
  {4, 3},
  # Eve's post
  {1, 4}
]

for {liker_idx, post_idx} <- like_pairs do
  liker = Enum.at(users, liker_idx)
  post = Enum.at(wall_posts, post_idx)
  Timeline.toggle_like(liker.id, "wall_post", post.id)
end

IO.puts("  Created #{length(like_pairs)} likes")

# ── Pokes ─────────────────────────────────────────────────────────
poke_pairs = [
  {0, 1},
  {1, 2},
  {2, 3},
  {3, 4},
  {4, 5},
  {5, 6},
  {6, 7},
  {7, 8},
  {8, 9},
  {9, 0}
]

for {poker_idx, pokee_idx} <- poke_pairs do
  poker = Enum.at(users, poker_idx)
  pokee = Enum.at(users, pokee_idx)
  Social.poke(poker.id, pokee.id)
end

IO.puts("  Created #{length(poke_pairs)} pokes")

# ── Friend Requests (pending) ────────────────────────────────────
# Users who are NOT already friends send requests
pending_requests = [
  {0, 5},
  {0, 6},
  {0, 7},
  {0, 8},
  {1, 4},
  {1, 6},
  {1, 7},
  {1, 8},
  {1, 9},
  {2, 5},
  {2, 7},
  {2, 8},
  {2, 9},
  {4, 6},
  {4, 7}
]

request_count = 0

for {sender_idx, receiver_idx} <- pending_requests do
  sender = Enum.at(users, sender_idx)
  receiver = Enum.at(users, receiver_idx)

  # Only create if they aren't already friends
  unless Social.friends?(sender.id, receiver.id) do
    Repo.insert!(%ParkBench.Social.FriendRequest{
      sender_id: sender.id,
      receiver_id: receiver.id,
      status: "pending"
    })
  end
end

IO.puts("  Created pending friend requests")

# ── Message Threads ───────────────────────────────────────────────
thread_conversations = [
  {0, 1, "Weekend plans?",
   [
     "Hey Bob, want to grab lunch this Saturday?",
     "Sure! How about that new place downtown?",
     "Perfect, let's do noon.",
     "Sounds great! See you there."
   ]},
  {2, 3, "Book club",
   [
     "David, have you finished the chapter yet?",
     "Almost! Just a few pages left.",
     "Great, we're meeting Thursday to discuss."
   ]},
  {4, 5, "Basketball game",
   [
     "Frank, are you coming to the game on Sunday?",
     "Wouldn't miss it! What time?",
     "Starts at 3pm. I'll save you a seat.",
     "Awesome, thanks Eve!",
     "No problem. Go team!"
   ]},
  {0, 2, "Project update",
   [
     "Carol, wanted to give you a quick update on the project.",
     "Sure, what's the latest?"
   ]},
  {6, 7, "Art show",
   [
     "Henry, there's an art show this weekend. Interested?",
     "Absolutely! What time does it open?",
     "10am. I'll meet you at the entrance."
   ]}
]

for {sender_idx, recipient_idx, subject, messages} <- thread_conversations do
  sender = Enum.at(users, sender_idx)
  recipient = Enum.at(users, recipient_idx)

  [first_msg | rest] = messages

  {:ok, %{thread: thread}} = Messaging.create_thread(sender.id, recipient.id, subject, first_msg)

  # Alternate sender/recipient for replies
  rest
  |> Enum.with_index()
  |> Enum.each(fn {body, idx} ->
    reply_sender = if rem(idx, 2) == 0, do: recipient, else: sender
    Messaging.reply_to_thread(thread.id, reply_sender.id, body)
  end)
end

IO.puts("  Created 5 message threads with replies")

# ── Notifications ─────────────────────────────────────────────────
notification_data = [
  # Friend request notifications
  {1, 0, "friend_request", "FriendRequest"},
  {2, 0, "friend_request", "FriendRequest"},
  {3, 0, "friend_request", "FriendRequest"},
  # Wall post notifications
  {0, 1, "wall_post", "WallPost"},
  {0, 2, "wall_post", "WallPost"},
  {1, 3, "wall_post", "WallPost"},
  # Comment notifications
  {0, 1, "wall_comment", "Comment"},
  {0, 2, "wall_comment", "Comment"},
  {1, 0, "wall_comment", "Comment"},
  {2, 0, "wall_comment", "Comment"},
  # Poke notifications
  {1, 0, "poke", "Poke"},
  {2, 1, "poke", "Poke"},
  {3, 2, "poke", "Poke"},
  # Friend accept notifications
  {0, 1, "friend_accept", "user"},
  {0, 2, "friend_accept", "user"},
  {1, 3, "friend_accept", "user"},
  # Message notifications
  {0, 1, "new_message", "message_thread"},
  {2, 3, "new_message", "message_thread"},
  {4, 5, "new_message", "message_thread"},
  {6, 7, "new_message", "message_thread"}
]

for {user_idx, actor_idx, type, target_type} <- notification_data do
  user = Enum.at(users, user_idx)
  actor = Enum.at(users, actor_idx)

  Repo.insert!(%Notification{
    user_id: user.id,
    actor_id: actor.id,
    type: type,
    target_type: target_type,
    target_id: Ecto.UUID.generate(),
    read_at: if(Enum.random([true, false]), do: DateTime.utc_now() |> DateTime.truncate(:second))
  })
end

IO.puts("  Created #{length(notification_data)} notifications")

IO.puts("\nSeeding complete!")
IO.puts("Login with: user1@example.com / password123!")
IO.puts("Admin login: admin@parkbench.app / admin123!admin")
IO.puts("")
IO.puts("Privacy notes:")
IO.puts("  - user3 (Carol Davis) has friends-only profile")
IO.puts("  - user7 (Grace Lee) has only_me on friend list, birthday, relationship")
IO.puts("  - user5 (Eve Martinez) has friends-only friend list")
