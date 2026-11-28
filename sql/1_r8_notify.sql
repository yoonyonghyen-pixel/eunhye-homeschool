-- 은혜의 홈스쿨 · R8 관리자 알림 메일 기록 (추가만 · 여러 번 실행해도 안전)
-- 기존 표(profiles, family_state, photos, notices, settings)는 전혀 바꾸지 않아요.
--
-- notify_log: 알림 메일을 보냈는지(sent) / 키가 없어 건너뛰었는지(skipped) / 실패했는지(error) 남기는 표.
--   · 읽기: 승인된 관리자만 (관리자 화면의 '알림 메일' 카드)
--   · 쓰기: Edge Function(notify-admin)이 service role 키로만 써요. 일반 회원·관리자 화면에서는 쓸 수 없어요.
--   · 같은 가입 신청에 메일이 두 번 가지 않도록, (profile_id, kind)마다 'sent' 행은 하나만 둘 수 있어요(아래 고유 색인).

create table if not exists public.notify_log (
  id bigserial primary key,
  profile_id uuid,                                   -- 알림 대상 회원 (profiles.id). 기록이 사라지지 않게 외래 키는 걸지 않아요.
  kind text not null default 'signup',               -- 알림 종류 (지금은 'signup' 하나)
  status text not null check (status in ('sent', 'skipped', 'error')),
  detail text not null default '',                   -- 사람이 읽을 짧은 설명 (비밀값은 절대 넣지 않아요)
  created_at timestamptz not null default now()
);

create index if not exists notify_log_created_idx on public.notify_log (created_at desc);
create index if not exists notify_log_profile_idx on public.notify_log (profile_id, kind);
-- 한 가입 신청 = 메일 한 통 (웹훅이 두 번 와도 두 번째는 여기서 막혀요)
create unique index if not exists notify_log_sent_once on public.notify_log (profile_id, kind) where status = 'sent';

alter table public.notify_log enable row level security;

drop policy if exists nl_sel on public.notify_log;
create policy nl_sel on public.notify_log for select using (public.is_admin());
-- insert/update/delete 정책은 일부러 만들지 않아요 → RLS를 건너뛰는 service role만 쓸 수 있어요.

revoke insert, update, delete on public.notify_log from anon, authenticated;
grant select on public.notify_log to authenticated;
