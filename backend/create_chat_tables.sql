-- Chat tables for direct messaging
-- Run this once in your Supabase SQL editor.

create table if not exists public.chat_conversations (
  id uuid primary key default gen_random_uuid(),
  user_1_id uuid not null references public.profiles(id) on delete cascade,
  user_2_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint chat_conversations_distinct_users check (user_1_id <> user_2_id),
  constraint chat_conversations_unique_pair unique (user_1_id, user_2_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(trim(content)) > 0),
  created_at timestamptz not null default now(),
  read_at timestamptz null
);

create index if not exists idx_chat_conversations_user_1 on public.chat_conversations(user_1_id);
create index if not exists idx_chat_conversations_user_2 on public.chat_conversations(user_2_id);
create index if not exists idx_chat_messages_conversation_created_at on public.chat_messages(conversation_id, created_at desc);

-- Optional RLS (if you later switch chat endpoints to user-scoped clients)
-- alter table public.chat_conversations enable row level security;
-- alter table public.chat_messages enable row level security;
