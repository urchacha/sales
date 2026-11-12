// =====================================================================
// G+ 견적서 설정 파일 (index.html 과 같은 폴더에 두세요)
// 여기서 저장 방식을 정하면 "데이터 저장 방식 선택" 화면이 나오지 않습니다.
// =====================================================================
window.GQ_CONFIG = {
  // 저장 방식
  //   'supabase' : Supabase DB 사용 → 바로 로그인 화면이 나옵니다 (아래 URL·키 필수)
  //   'local'    : DB 없이 data.json + 브라우저 저장 (JSON 모드)
  //   'auto'     : 처음 접속할 때 선택 화면 표시
  DATA_MODE: 'supabase',

  // Supabase → Project Settings → API (또는 Connect) 에 있는 값
  //   Project URL     예) https://abcdefghijkl.supabase.co
  //   anon public key 예) eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9....
  // anon key 는 브라우저에 공개되어도 되는 키입니다.
  // service_role 키는 절대 넣지 마세요.
  SUPABASE_URL: 'https://mhvzaodkhkwosdwlvibu.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1odnphb2RraGt3b3Nkd2x2aWJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQyODE2NjgsImV4cCI6MjEwOTg1NzY2OH0.94OgYw-9uLshDJZEf3bVZnnHz5Y1u7iU4AQbn6M-jFs',

  // JSON 모드에서 불러올 데이터 파일
  DATA_JSON_URL: 'data.json',
};