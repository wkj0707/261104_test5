-- 기존 VPD SQL 설치가 완료된 프로젝트의 승인제 전환용 SQL
-- 기존 설치에서 중복 정책 오류 없이 실행하도록 기존 정책을 삭제 후 재생성합니다.
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
-- 첫 관리자 지정 예시: 실제 회원가입 후 SQL Editor에서 이메일 수정하여 별도로 실행
-- update public.vpd_members set role='admin' where user_id=(select id from auth.users where email='admin@company.com');

-- 최초 관리자 지정: 아래 이메일을 실제 관리자 이메일로 바꾸고 SQL Editor에서 실행
-- update public.vpd_members set role='admin',approval_status='approved',approved_at=now()
-- where user_id=(select id from auth.users where email='admin@company.com');
-- 주의: SQL Editor는 강한 권한으로 실행되므로 관리자 이메일을 정확히 확인하세요.
