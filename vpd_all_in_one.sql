-- VPD 단일 설치/복구 SQL (기존 다른 사이트 테이블은 절대 삭제하지 않음)
-- 주의: SQL Editor에 저장된 쿼리 삭제는 실제 DB 테이블/계정 삭제가 아닙니다.
-- 비밀번호는 SQL/HTML에 저장하지 않습니다. Supabase Auth에서 관리합니다.
-- 관리자 계정이 이미 있다면 아래 SQL은 관리자 권한만 지정합니다.
-- 비밀번호 오류 시 community.html의 '비밀번호 찾기'로 재설정하세요.

-- VPD 협업 게시판 설치 SQL: Supabase SQL Editor에서 실행
-- 다른 사이트와 구분하기 위해 모든 사용자 테이블에 vpd_ 접두어 사용
-- 비밀번호는 auth.users에서 Supabase Auth가 관리합니다.
create extension if not exists pgcrypto;
create table if not exists public.vpd_members (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '회원' check (char_length(display_name) between 1 and 60),
 role text not null default 'member' check (role in ('member','admin')),
 approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected')),
 approved_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists public.vpd_posts (
 id uuid primary key default gen_random_uuid(),
 board text not null check (board in ('notice','free','files','gallery')),
 author_id uuid not null references auth.users(id) on delete cascade,
 title text not null check (char_length(title) between 1 and 150),
 body text not null default '',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.vpd_attachments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.vpd_posts(id) on delete cascade,
 uploader_id uuid not null references auth.users(id) on delete cascade,
 object_path text not null unique,
 filename text not null,
 mime_type text,
 file_size bigint not null check (file_size between 0 and 10485760),
 created_at timestamptz not null default now()
);
create index if not exists vpd_posts_board_date_idx on public.vpd_posts(board,created_at desc);
create index if not exists vpd_attachments_post_idx on public.vpd_attachments(post_id);
-- 신규 가입 회원을 VPD 전용 회원 테이블에 자동 등록 (권한은 항상 member)
create or replace function public.vpd_register_member() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.vpd_members(user_id,display_name,role)
 values(new.id,coalesce(nullif(left(trim(new.raw_user_meta_data->>'display_name'),60),''),'회원'),'member')
 on conflict(user_id) do nothing;
 return new;
end $$;
drop trigger if exists vpd_auth_member_created on auth.users;
create trigger vpd_auth_member_created after insert on auth.users for each row execute function public.vpd_register_member();
-- 기존 Auth 사용자도 누락 없이 기본 회원으로 등록 (기존 권한은 유지)
insert into public.vpd_members(user_id,display_name)
select id,coalesce(nullif(left(trim(raw_user_meta_data->>'display_name'),60),''),'회원') from auth.users on conflict(user_id) do nothing;
-- 권한 판단: 사용자 본인이 자신의 role을 변경할 수 없도록 함수와 RLS 사용
create or replace function public.vpd_is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.vpd_members where user_id=(select auth.uid()) and role='admin');
$$;
revoke all on function public.vpd_is_admin() from public;
grant execute on function public.vpd_is_admin() to authenticated;
-- 수정시간 자동 기록
create or replace function public.vpd_touch_post() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at=now(); return new; end $$;
drop trigger if exists vpd_posts_touch on public.vpd_posts;
create trigger vpd_posts_touch before update on public.vpd_posts for each row execute function public.vpd_touch_post();
-- 기존 설치에도 적용 가능한 승인 상태 필드 추가
alter table public.vpd_members add column if not exists approval_status text not null default 'pending';
alter table public.vpd_members add column if not exists approved_at timestamptz;
-- 기존 관리자는 서비스 중단 없이 승인 상태로 변경. 일반 회원은 관리자가 다시 승인해야 함.
update public.vpd_members set approval_status='approved', approved_at=coalesce(approved_at,now()) where role='admin';
alter table public.vpd_members drop constraint if exists vpd_members_approval_status_check;
alter table public.vpd_members add constraint vpd_members_approval_status_check check (approval_status in ('pending','approved','rejected'));
-- 승인된 회원 여부를 DB에서 판정 (브라우저 조작으로 우회 불가)
create or replace function public.vpd_is_approved() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.vpd_members where user_id=(select auth.uid()) and approval_status='approved');
$$;
revoke all on function public.vpd_is_approved() from public;
grant execute on function public.vpd_is_approved() to authenticated;
-- 일반 사용자는 자기 프로필만, 관리자는 모든 회원을 볼 수 있음
alter table public.vpd_members enable row level security;
alter table public.vpd_posts enable row level security;
alter table public.vpd_attachments enable row level security;
drop policy if exists "vpd_members_read" on public.vpd_members;
drop policy if exists "vpd_members_admin_update" on public.vpd_members;
create policy "vpd_members_read" on public.vpd_members for select to authenticated using (user_id=(select auth.uid()) or (select public.vpd_is_admin()));
create policy "vpd_members_admin_update" on public.vpd_members for update to authenticated using ((select public.vpd_is_admin())) with check ((select public.vpd_is_admin()));
-- 일반 회원의 승인/권한 변경 차단은 RLS와 아래 권한 설정으로 이중 보호
-- 게시판의 모든 읽기/쓰기에는 승인 상태 확인을 적용
drop policy if exists "vpd_posts_read" on public.vpd_posts;
drop policy if exists "vpd_posts_insert" on public.vpd_posts;
drop policy if exists "vpd_posts_update" on public.vpd_posts;
drop policy if exists "vpd_posts_delete" on public.vpd_posts;
create policy "vpd_posts_read" on public.vpd_posts for select to authenticated using ((select public.vpd_is_approved()));
create policy "vpd_posts_insert" on public.vpd_posts for insert to authenticated with check ((select public.vpd_is_approved()) and author_id=(select auth.uid()) and (board <> 'notice' or (select public.vpd_is_admin())));
create policy "vpd_posts_update" on public.vpd_posts for update to authenticated using ((select public.vpd_is_approved()) and (author_id=(select auth.uid()) or (select public.vpd_is_admin())) and (board <> 'notice' or (select public.vpd_is_admin()))) with check ((select public.vpd_is_approved()) and (author_id=(select auth.uid()) or (select public.vpd_is_admin())) and (board <> 'notice' or (select public.vpd_is_admin())));
create policy "vpd_posts_delete" on public.vpd_posts for delete to authenticated using ((select public.vpd_is_approved()) and (author_id=(select auth.uid()) or (select public.vpd_is_admin())));
-- 작성자/게시판 변경을 막아 타인의 글이나 공지 권한 우회를 차단
create or replace function public.vpd_protect_post() returns trigger language plpgsql set search_path = '' as $$
begin
 if new.author_id is distinct from old.author_id or new.board is distinct from old.board then
 raise exception '작성자와 게시판 종류는 변경할 수 없습니다'; end if;
 return new;
end $$;
drop trigger if exists vpd_posts_protect on public.vpd_posts;
create trigger vpd_posts_protect before update on public.vpd_posts for each row execute function public.vpd_protect_post();
drop policy if exists "vpd_files_read" on public.vpd_attachments;
drop policy if exists "vpd_files_insert" on public.vpd_attachments;
drop policy if exists "vpd_files_delete" on public.vpd_attachments;
create policy "vpd_files_read" on public.vpd_attachments for select to authenticated using ((select public.vpd_is_approved()));
create policy "vpd_files_insert" on public.vpd_attachments for insert to authenticated with check ((select public.vpd_is_approved()) and uploader_id=(select auth.uid()) and exists(select 1 from public.vpd_posts p where p.id=post_id and p.author_id=(select auth.uid())));
create policy "vpd_files_delete" on public.vpd_attachments for delete to authenticated using ((select public.vpd_is_approved()) and (uploader_id=(select auth.uid()) or (select public.vpd_is_admin())));
-- 전용 비공개 스토리지: 10MB 제한, 지정 확장자만 허용
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('vpd-files','vpd-files',false,10485760,array['application/pdf','image/png','image/jpeg','image/webp','text/plain','text/csv','application/zip','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.openxmlformats-officedocument.presentationml.presentation'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
-- 파일 경로는 user_id/post_id/파일명 형식으로 저장
drop policy if exists "vpd_storage_read" on storage.objects;
drop policy if exists "vpd_storage_insert" on storage.objects;
drop policy if exists "vpd_storage_delete" on storage.objects;
create policy "vpd_storage_read" on storage.objects for select to authenticated using (bucket_id='vpd-files' and (select public.vpd_is_approved()));
create policy "vpd_storage_insert" on storage.objects for insert to authenticated with check (bucket_id='vpd-files' and (select public.vpd_is_approved()) and (storage.foldername(name))[1]=(select auth.uid())::text and exists(select 1 from public.vpd_posts p where p.id::text=(storage.foldername(name))[2] and p.author_id=(select auth.uid())));
create policy "vpd_storage_delete" on storage.objects for delete to authenticated using (bucket_id='vpd-files' and (select public.vpd_is_approved()) and ((storage.foldername(name))[1]=(select auth.uid())::text or (select public.vpd_is_admin())));
-- 최소 권한: 회원 테이블의 role 변경은 SQL Editor 관리자만 수행
revoke all on public.vpd_members,public.vpd_posts,public.vpd_attachments from anon;
grant select on public.vpd_members to authenticated;
-- 관리자만 UPDATE 허용 여부는 RLS에서 검사합니다.
grant update(approval_status,approved_at) on public.vpd_members to authenticated;
grant select,insert,update,delete on public.vpd_posts to authenticated;
grant select,insert,delete on public.vpd_attachments to authenticated;

-- ================================================================
-- 최초 관리자 계정 지정 (비밀번호는 Supabase Auth에서만 설정)
-- 사전 조건: Authentication > Users에 아래 이메일 계정이 존재해야 합니다.
-- 계정이 아직 없다면 Dashboard > Authentication > Users > Add user에서
-- 해당 이메일과 비밀번호를 직접 설정한 뒤 이 통합 SQL을 다시 실행하세요.
-- SQL을 재실행해도 기존 게시글/회원 정보는 삭제하지 않습니다.
-- ================================================================
insert into public.vpd_members(user_id,display_name,role,approval_status,approved_at)
select id, coalesce(nullif(left(trim(raw_user_meta_data->>'display_name'),60),''),'VPD 관리자'),
       'admin','approved',now()
from auth.users where lower(email)=lower('kwangjae.won@hd.com')
on conflict(user_id) do update
set role='admin',approval_status='approved',approved_at=now();

-- 관리자 설정 확인: 결과가 0행이면 Auth 계정부터 생성해야 합니다.
select u.email,m.role,m.approval_status,(u.email_confirmed_at is not null) as email_verified
from auth.users u join public.vpd_members m on m.user_id=u.id
where lower(u.email)=lower('kwangjae.won@hd.com');
