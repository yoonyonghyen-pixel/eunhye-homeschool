-- 은혜의 홈스쿨 · R10 '보류' 표시 칸 (추가만 · 여러 번 실행해도 안전)
-- 기존 표·기존 함수(admin_set_member 등)·기존 데이터는 전혀 바꾸지 않아요. 새 칸 1개·새 함수 2개·새 트리거 1개만 더해요.
--
-- 왜 필요해요? (review-r9 M1)
--   서버의 회원 상태는 pending(승인 대기)·approved(승인됨)·suspended(정지) 셋뿐이라,
--   관리자가 '보류'(승인 전에 멈춤)를 눌러도 '정지'와 구별할 칸이 없었어요.
--   그래서 화면이 "정지인데 기록이 없으면 보류"로 짐작했는데, 승인된 뒤 아직 기록이 없는 가정을 정지하면 '보류'로 잘못 보였어요.
--   이 파일을 적용하면 보류한 때(held_at)를 서버가 직접 기억해서, 화면이 짐작하지 않아도 돼요.
--
-- 규칙
--   · held_at: 보류한 시각. 비어 있으면(null) 보류가 아니에요. 기존 회원은 모두 비어 있는 채로 시작해요.
--   · admin_set_hold(p_id): 관리자만. '승인 대기' 회원만 보류할 수 있어요. 상태를 정지로 바꾸고 held_at을 한 번에 채워요.
--   · 승인되면(status → approved) held_at은 트리거가 자동으로 지워요. 그래서 나중에 진짜로 '정지'하면 '정지'로 보여요.

alter table public.profiles add column if not exists held_at timestamptz;

create or replace function public.admin_set_hold(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception '관리자만 할 수 있어요'; end if;
  if p_id = auth.uid() then raise exception '자기 자신은 보류할 수 없어요'; end if;
  update profiles set status = 'suspended', held_at = now() where id = p_id and status = 'pending';
  if not found then raise exception '승인 대기 중인 회원만 보류할 수 있어요'; end if;
end $$;
revoke execute on function public.admin_set_hold(uuid) from public;
revoke execute on function public.admin_set_hold(uuid) from anon;
grant execute on function public.admin_set_hold(uuid) to authenticated;   -- 로그인한 사람만 부를 수 있고, 함수 안에서 관리자인지 다시 확인해요

create or replace function public.profiles_clear_hold() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.status = 'approved' then new.held_at := null; end if;
  return new;
end $$;
drop trigger if exists profiles_clear_hold on public.profiles;
create trigger profiles_clear_hold before update of status on public.profiles
  for each row execute function public.profiles_clear_hold();
