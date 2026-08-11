# 파티 보드 배포 가이드

GitHub Pages + Supabase 무료 조합으로 여러 사람이 같은 파티 보드를 공유할 수 있습니다.

## 1. Supabase 프로젝트 만들기

1. [supabase.com](https://supabase.com) 가입 후 **New project** 생성
2. Dashboard → **SQL Editor** → `supabase/schema.sql` 내용 전체 붙여넣기 → **Run**
   - 테이블: `party_board_state`(version), `app_settings`, `presence`, `login_logs`, `chat_messages`
   - Realtime: `party_board_state`, `presence`, `chat_messages`
3. Dashboard → **Database → Replication** 에서 위 테이블 Realtime 확인
4. Dashboard → **Project Settings → API** 에서 Project URL / anon key 복사

### 입장 비밀번호

- 기본값: `party` (SHA-256으로 DB에 저장)
- 변경하려면 새 비밀번호의 SHA-256 hex를 `app_settings.room_password_hash`에 넣으세요.

```sql
-- 예: 비밀번호를 newpass 로 바꿀 때 (브라우저 콘솔에서 sha256 후 붙여넣기)
UPDATE app_settings
SET value = '여기에_SHA256_HEX'
WHERE key = 'room_password_hash';
```

입장 시 `login_logs`에 닉네임·공개 IP·UA·시각이 기록됩니다. (Table Editor에서 확인)

### 채팅

- `chat_messages` 테이블 + Realtime INSERT 구독
- schema.sql 재실행 후 Dashboard → Replication에서 `chat_messages` 확인

## 2. 로컬 설정

```bash
copy config.example.js config.js
```

`config.js` 를 열어 URL과 anon key를 입력합니다.

```javascript
window.SUPABASE_CONFIG = {
  url: "https://xxxxx.supabase.co",
  anonKey: "eyJhbGciOi..."
};
```

로컬에서 `index.html` 을 브라우저로 열거나, Live Server 등으로 테스트합니다.

## 3. GitHub 저장소 & Pages

필요한 파일만 올립니다.

```
index.html
config.js
config.example.js
supabase/schema.sql
.gitignore
DEPLOY.md
```

> `config.js` 는 `.gitignore` 에 포함되어 있어 GitHub에 올라가지 않습니다.  
> GitHub Pages에서는 **Settings → Secrets and variables → Actions** 또는 아래 방법 B를 사용하세요.

### 방법 A — config.js를 GitHub에 포함 (가장 간단)

익명 키(anon key)는 클라이언트에 노출되는 공개 키입니다. RLS로 보호하므로, 소규모 파티 보드라면 `config.js` 를 저장소에 포함해도 됩니다.

1. GitHub에 새 저장소 생성
2. 파일 push
3. 저장소 **Settings → Pages**
   - Source: **Deploy from a branch**
   - Branch: `main` / `/ (root)`
4. 몇 분 후 `https://YOUR_USERNAME.github.io/REPO_NAME/` 접속

### 방법 B — GitHub Actions로 config.js 생성 (config.js 미포함 시)

`.github/workflows/pages.yml` 예시:

```yaml
name: Deploy Pages
on:
  push:
    branches: [main]
permissions:
  contents: read
  pages: write
  id-token: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create config.js
        run: |
          cat > config.js <<'EOF'
          window.SUPABASE_CONFIG = {
            url: "${{ secrets.SUPABASE_URL }}",
            anonKey: "${{ secrets.SUPABASE_ANON_KEY }}"
          };
          EOF
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: .
      - uses: actions/deploy-pages@v4
```

Repository Secrets에 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 등록 후 push.

## 4. 동작 확인

1. PC 브라우저에서 Pages URL 접속 → 닉네임 입력 → 파티 생성
2. 모바일 또는 다른 PC에서 같은 URL 접속 → 동일한 파티가 보이는지 확인
3. 한쪽에서 슬롯 변경 시 다른 쪽에 Realtime 또는 5초 이내 반영되는지 확인

## 보안 참고

- 현재 RLS는 **누구나 읽기/쓰기 가능**합니다. 공개 파티 모집용으로 적합합니다.
- 악의적 사용자가 보드를 초기화할 수 있으므로, 필요하면 Supabase Auth 또는 간단한 공유 비밀번호를 추가하세요.

## 문제 해결

| 증상 | 확인 |
|------|------|
| 상단에 Supabase 설정 오류 | `config.js` 존재 및 URL/key 확인 |
| 저장은 되는데 다른 기기에 안 보임 | SQL 실행 여부, Realtime 활성화 |
| CORS/네트워크 오류 | Supabase 프로젝트가 paused 상태인지 확인 (무료 tier 7일 미사용 시) |
