# VPD 협업 게시판 설치 안내

1. Supabase Dashboard → SQL Editor → New query에서 `vpd_setup.sql` **파일 내용 전체를 붙여넣고 Run**을 누릅니다. SQL 파일은 Storage에 업로드하는 것이 아닙니다.
2. Authentication → Providers에서 Email 가입을 활성화하고, URL Configuration에 실제 배포 사이트 주소를 설정합니다. 이메일 인증을 켜면 인증 메일 확인 후 로그인합니다.
3. `community.html`에 사용자 제공 Supabase URL과 publishable key가 설정되어 있습니다. 서버용 secret/service_role 키는 HTML에 넣지 마세요.
4. 회원가입 후 SQL Editor에서 `update public.vpd_members set role='admin' where user_id=(select id from auth.users where email='관리자이메일');` 을 실행하여 관리자를 지정합니다. SQL의 예시 이메일을 그대로 실행하지 마세요.
5. `index.html`, `community.html`, `admin.html`, `queue.html`, 이미지 파일을 같은 경로에 배포합니다. 테스트: 해당 폴더에서 `python -m http.server 8000` 실행 후 `http://localhost:8000/index.html` 접속.
6. 새 게시판은 Supabase DB/Storage에 저장됩니다. **기존 해석 업무 신청·승인·첨부파일은 여전히 브라우저 로컬 저장 방식**이며, `admin.html`의 1111은 시연용입니다. 실제 사내 개인정보/기밀자료를 기존 업무 기능에 입력하지 마세요.
7. Storage는 비공개 버킷이며 파일당 10MB 제한입니다. 자료실은 문서, 갤러리는 이미지 첨부가 가능합니다. 이번 버전은 게시글당 새 파일 1개, 기존 첨부파일 교체/개별 삭제 및 댓글은 미지원입니다.
8. 동일 Supabase 프로젝트의 Auth 사용자 계정은 전역 공유됩니다. 사이트별 `vpd_members`처럼 프로필·권한·게시글을 분리할 수 있지만, **인증 계정 자체까지 완전히 분리되는 것은 아닙니다.**
9. 초기 운영 전 RLS, 첨부 접근권한, 가입 제한 정책을 별도로 검증하세요. 회사 도메인만 가입시키려면 클라이언트 검사만으로는 부족하고 서버 측 가입 정책이 필요합니다.
10. 재설치용 SQL은 최초 1회 실행을 전제로 합니다. 이미 동일 이름의 정책이 있으면 중복 오류가 발생할 수 있습니다. 기존 운영 DB에는 백업과 검토 없이 재실행하지 마세요.
