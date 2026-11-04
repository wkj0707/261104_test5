# VPD 통합 설치 안내

## 중요: 데이터 삭제 금지
- Supabase SQL Editor의 **저장된 쿼리 삭제**는 데이터베이스 테이블 삭제가 아닙니다.
- 기존 `vpd_setup.sql`, `vpd_approval_migration.sql` 쿼리를 삭제할 필요가 없습니다.
- `DROP TABLE`, `DELETE FROM auth.users` 등으로 기존 DB를 초기화하지 마세요.
- 제공된 `vpd_unified_setup.sql` **한 파일만** SQL Editor에서 실행합니다. 기존 VPD 테이블이 있어도 다시 실행할 수 있도록 작성했습니다.

## 관리자 계정 설정
1. Supabase Dashboard → Authentication → Users에서 `kwangjae.won@hd.com` 계정이 있는지 확인합니다.
2. 없다면 **Add user**로 계정을 생성하고, Dashboard에서 직접 비밀번호를 지정합니다. 이메일 인증 여부도 확인합니다.
3. 이미 있다면 Dashboard의 비밀번호 재설정 기능을 사용합니다. HTML/SQL에 비밀번호를 기록하지 마세요.
4. SQL Editor → New query에서 `vpd_unified_setup.sql` 전체를 붙여넣고 Run을 누릅니다.
5. 마지막 SELECT 결과에 `role=admin`, `approval_status=approved`, `email_verified=true`가 표시되는지 확인합니다.
6. 계정을 SQL 실행 이후 생성했다면 **같은 통합 SQL을 한 번 더 실행**하여 관리자 권한을 지정합니다.

## 가입/승인/글쓰기 검증
1. `community.html`에서 관리자 이메일로 로그인 → 아래쪽 `회원 가입 승인 관리` 확인.
2. 다른 이메일로 회원가입 → 이메일 인증 → 승인 대기 표시 확인.
3. 관리자로 로그인 → 신청자 승인.
4. 일반 회원으로 다시 로그인 → 자유게시판에서 글쓰기/저장/목록/상세 확인.
5. 공지사항은 관리자만 작성 가능. 자료실·갤러리는 10MB 이내 파일을 첨부할 수 있습니다.

## 배포
- 모든 HTML과 이미지 파일을 같은 웹 경로에 업로드합니다.
- GitHub Pages 등 HTTPS 웹서버에서 테스트하세요. 로컬 테스트: `python -m http.server 8000`.
- Supabase Authentication → URL Configuration에서 Site URL과 Redirect URLs를 배포 주소로 설정합니다.
- Email provider 및 이메일 인증 옵션을 확인합니다.
- 공개 가능한 publishable key만 HTML에 있습니다. service_role/secret 키를 넣지 마세요.

## 범위와 제한
- Supabase DB는 **커뮤니티 게시판/회원/첨부파일**에 연결되어 있습니다.
- 기존 `index.html`, `queue.html`, `admin.html`의 업무 데이터는 원본의 localStorage 기반으로 유지됩니다. `admin.html`의 시연용 관리자 인증은 별도이므로 민감한 사내 데이터를 저장하지 마세요.
- 한 Supabase 프로젝트 내 VPD 테이블에 `vpd_` 접두어를 사용합니다. Auth 계정은 프로젝트 전체에서 공유됩니다.
- 브라우저에서 직접 Supabase와 연결하므로 온라인 배포 환경에서 실제 가입/승인/파일 테스트가 필요합니다.
- 이 패키지에 관리자 비밀번호를 하드코딩하지 않았습니다. 채팅에 입력한 비밀번호는 노출된 것으로 간주하고 새 비밀번호로 변경하는 것을 권장합니다.
