-- =========================================================
-- HAND LOG : Supabase のテーブルと権限ルール
-- Supabase の「SQL Editor」にこのファイルを丸ごと貼り付けて Run
-- =========================================================

-- 利用者のプロフィール（ニックネーム）
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  nick       text not null default '' check (char_length(nick) <= 24),
  created_at timestamptz not null default now()
);

-- ハンド（1ハンド = 1行。中身は JSON でまるごと保存）
create table if not exists public.hands (
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id         text not null check (char_length(id) <= 64),
  t          bigint not null,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists hands_user_t on public.hands (user_id, t);

-- 設定と AI コーチの最新レポート（1人1行）
create table if not exists public.user_meta (
  user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  settings   jsonb,
  coach      jsonb,
  updated_at timestamptz not null default now()
);

-- 管理者（全員のデータを見られる人）
create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

-- AI コーチの利用記録（1日の回数制限に使う）
create table if not exists public.coach_runs (
  id      bigserial primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  at      timestamptz not null default now()
);
create index if not exists coach_runs_user_at on public.coach_runs (user_id, at);

-- 自分が管理者かどうか
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- ---------- 権限ルール（Row Level Security） ----------
alter table public.profiles   enable row level security;
alter table public.hands      enable row level security;
alter table public.user_meta  enable row level security;
alter table public.admins     enable row level security;
alter table public.coach_runs enable row level security;

-- profiles: 本人は読み書き、管理者は全員分を読める
drop policy if exists "profiles read"   on public.profiles;
drop policy if exists "profiles insert" on public.profiles;
drop policy if exists "profiles update" on public.profiles;
create policy "profiles read"   on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "profiles insert" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- hands: 本人は読み書き削除、管理者は全員分を読める（書き換えはできない）
drop policy if exists "hands read"   on public.hands;
drop policy if exists "hands insert" on public.hands;
drop policy if exists "hands update" on public.hands;
drop policy if exists "hands delete" on public.hands;
create policy "hands read"   on public.hands for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "hands insert" on public.hands for insert to authenticated with check (user_id = auth.uid());
create policy "hands update" on public.hands for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "hands delete" on public.hands for delete to authenticated using (user_id = auth.uid());

-- user_meta: 本人だけ
drop policy if exists "meta own" on public.user_meta;
create policy "meta own" on public.user_meta for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- admins: アプリからは誰も読み書きできない（SQL Editor からだけ登録する）

-- coach_runs: 本人だけ読める・追加できる
drop policy if exists "runs read"   on public.coach_runs;
drop policy if exists "runs insert" on public.coach_runs;
create policy "runs read"   on public.coach_runs for select to authenticated using (user_id = auth.uid());
create policy "runs insert" on public.coach_runs for insert to authenticated with check (user_id = auth.uid());

-- ログインした人にだけテーブルを使わせる（未ログインは何もできない）
revoke all on public.profiles, public.hands, public.user_meta, public.admins, public.coach_runs from anon;
grant select, insert, update          on public.profiles   to authenticated;
grant select, insert, update, delete  on public.hands      to authenticated;
grant select, insert, update, delete  on public.user_meta  to authenticated;
grant select, insert                  on public.coach_runs to authenticated;
grant usage, select on sequence public.coach_runs_id_seq   to authenticated;
grant execute on function public.is_admin() to authenticated;

-- =========================================================
-- 管理者の登録（自分がアプリで新規登録したあとに、メールアドレスを書き換えて実行）
-- insert into public.admins (user_id)
--   select id from auth.users where email = 'あなたのメールアドレス';
-- =========================================================
