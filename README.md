# G+ 견적서 웹

| 파일 | 내용 |
|---|---|
| `index.html` | 견적서 화면 (작성 · 목록 · 거래처 · 회사정보 · 인쇄) |
| `data.json` | DB 없이 쓰는 JSON 모드용 데이터 (회사정보, 거래처, 가격표) |
| `vercel.json` | Vercel 설정 (data.json 캐시 끄기, 검색엔진 노출 막기) |

## 데이터 저장 방식

`index.html` 맨 위의 `DATA_MODE` 값으로 정합니다.

- `'auto'` (기본): 처음 접속할 때 "JSON 모드"와 "Supabase 연결" 중에서 고릅니다.
- `'local'`: 항상 JSON 모드로 엽니다. 선택 화면이 나오지 않습니다.
- `'supabase'`: 항상 Supabase로 엽니다. `SUPABASE_URL`, `SUPABASE_ANON_KEY`도 함께 입력하세요.

### JSON 모드의 동작

- 처음 열 때 `data.json`의 가격표, 거래처, 회사정보를 불러옵니다.
- 작성한 견적, 새로 추가한 거래처, 바꾼 회사정보는 **그 PC 브라우저에만** 저장됩니다. 다른 PC나 다른 직원과는 공유되지 않습니다.
- 상단의 **JSON 내보내기**로 전체 데이터를 파일로 백업하고, **JSON 가져오기**로 복원하거나 다른 PC로 옮깁니다.
- 브라우저 기록이나 쿠키를 지우면 저장된 데이터도 함께 사라집니다. 정기적으로 내보내기를 해 두세요.

### 가격표 바꾸기

1. `data.json`의 `price_list`를 수정합니다.
2. **`version` 값을 바꿉니다.** 예: `"2026-12-01"`
3. 다시 배포합니다.

각 PC가 다음에 접속하면 가격표만 새것으로 바뀌고, 거래처와 견적은 그대로 유지됩니다.

## Vercel 배포

### 방법 A: GitHub 연결 (권장, 수정할 때마다 자동 배포)

1. 이 폴더를 GitHub 저장소로 올립니다. 저장소는 **Private**로 만드세요.
2. https://vercel.com 에서 GitHub 계정으로 로그인합니다.
3. **Add New… → Project**를 누르고, 저장소 옆의 **Import**를 누릅니다.
4. 설정 화면에서 다음과 같이 둡니다.
   - Framework Preset: **Other**
   - Root Directory: `index.html`이 있는 폴더 (저장소 맨 위에 있으면 그대로)
   - Build Command / Output Directory: 비워 둡니다.
5. **Deploy**를 누르면 `https://프로젝트명.vercel.app` 주소가 생깁니다.
6. 이후에는 VS Code에서 커밋하고 동기화(push)하면 1분 안에 자동으로 다시 배포됩니다.

### 방법 B: 명령어로 바로 배포

Node.js가 설치되어 있어야 합니다. VS Code 터미널에서 실행하세요.

```bash
cd gplus-quote
npx vercel           # 처음: 로그인 → 질문에 Enter → 미리보기 주소 생성
npx vercel --prod    # 실제(운영) 주소로 배포
```

## 보안 주의

- **JSON 모드**에서는 `data.json`이 누구나 내려받을 수 있는 공개 파일입니다. 주소를 아는 사람은 가격표(특별대리점가 포함)와 거래처 목록을 볼 수 있습니다.
  - 외부 공개를 막으려면 Vercel **Settings → Deployment Protection**에서 비밀번호 보호를 켜야 합니다(유료 플랜). 또는 Supabase 모드를 쓰세요.
  - 위안화, 원가, 입고가는 처음부터 `data.json`에 넣지 않았습니다.
- **Supabase 모드**는 로그인한 직원만 데이터를 볼 수 있습니다. `index.html`에 넣는 anon key는 공개되어도 괜찮은 키입니다. `service_role` 키는 절대 넣지 마세요.
