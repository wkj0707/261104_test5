# VPD 재설치 안내 — SQL 파일 하나

## 중요: 삭제하지 마세요
- Supabase SQL Editor에서 **쿼리 탭/기록을 삭제해도 DB는 초기화되지 않습니다**.
- `auth.users`, `public.vpd_members`, `public.vpd_posts`, `storage.objects`를 직접 삭제하지 마세요. 다른 사이트 데이터에도 영향을 줄 수 있습니다.
- 이번 SQL은 기존 VPD 테이블/게시글을 보존하며 재실행할 수 있게 구성했습니다. **실제 운영 데이터가 있다면 백업 후 진행하세요.**

## 1. DB 설치
1. Supabase 프로젝트 → SQL Editor → New query.
2. **`vpd_all_in_one.sql` 한 개만** 전체 붙여넣고 Run.
3. 마지막 SELECT 결과에서 `kwangjae.won@hd.com`의 `role=admin`, `approval_status=approved`, `email_verified=true` 확인.

## 2. 관리자 비밀번호 설정 (중요)
- 관리자 이메일: `kwangjae.won@hd.com`.
- **비밀번호는 SQL로 설정되지 않습니다.** 이미 가입한 계정의 비밀번호가 틀리면 웹사이트 로그인 창의 **비밀번호 찾기**를 누르세요.
- Supabase Authentication → URL Configuration의 Site URL을 `https://wkj0707.github.io/261104_test5/`로, Redirect URLs에 `https://wkj0707.github.io/261104_test5/**`를 추가하세요.
- 비밀번호 복구 이메일 링크에서 새 비밀번호를 설정합니다. 기존에 대화에 공개한 비밀번호는 재사용하지 않는 것이 안전합니다.
- 관리자 계정이 Auth에 없다면 `community.html`에서 회원가입 후 이메일 인증을 하고 **동일 SQL을 재실행**하여 관리자 권한을 부여하세요.
- **HTML이나 공개 SQL에 비밀번호를 하드코딩하면 누구나 볼 수 있어 그렇게 구현하지 않았습니다.**

## 3. 배포
- ZIP의 HTML 4개 및 이미지들을 GitHub Pages 동일 폴더에 업로드하세요.
- 기존 `index.html`, `admin.html`, `queue.html`의 업무 데이터는 브라우저 로컬 저장이며 커뮤니티 게시판만 Supabase 연동입니다.

## 4. 동작 테스트
1. 관리자 로그인 → 관리자 승인 상태 확인.
2. 다른 이메일로 가입 → 이메일 확인 → 승인 대기 확인.
3. 관리자 로그인 → '회원 가입 승인 관리'에서 승인.
4. 일반 회원 로그인 → 자유게시판 글 작성 → 새로고침 후 글이 유지되는지 확인.
5. 자료실 파일 업로드/다운로드와 비회원 접근 차단 확인.

**실제 Supabase 운영 환경에서 E2E 검증은 수행하지 않았습니다.** 오류 발생 시 개발자 도구 Console 및 Supabase Auth Logs를 확인하세요.
