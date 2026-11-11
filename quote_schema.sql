-- =====================================================================
-- 견적서 시스템 테이블 (Supabase / PostgreSQL 15+)
-- 선행: price_list.sql (가격표 테이블)이 먼저 실행되어 있어야 합니다.
-- 여러 번 실행해도 안전하도록 작성되었습니다.
-- =====================================================================

-- updated_at 자동 갱신 함수 (price_list.sql 에도 있음)
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at := now(); return new; end $$;

-- ---------------------------------------------------------------------
-- 1. 우리 회사 정보 (견적서 우측 상단 공급자 정보, 1행만 사용)
-- ---------------------------------------------------------------------
create table if not exists public.company_profile (
  id              smallint primary key default 1 check (id = 1),
  company_name    text not null default '㈜ 지플러스코리아',
  brand_name      text default 'G Plus KOREA',   -- (현재 견적서에 표시 안 함)
  address_line1   text default '경기도 부천시 조마루로385번길 122',
  address_line2   text default '삼보테크노타워 1층 130호',
  address_en      text default '130ho, sambotechno tower 122 / Jomaru-ro 385beon-gil, Bucheon-si, Gyeonggi-do',
  email           text default 'gplus@gpluskorea.kr',
  fax             text default '0303-3443-8179',
  manager_name    text default '김좌환 부장',
  manager_phone   text default '010-9183-8993',
  logo_url        text,           -- 로고 이미지 URL (선택)
  stamp_url       text,           -- 직인 이미지 URL (선택)
  default_notes   text default E'1. 견적 유효 기간 : 견적일로부터 30일\n2. 납품 장소 : 사용자 지정 장소\n3. 대금지불조건 : 정기결제',
  quote_prefix    text default 'GK',
  updated_at      timestamptz not null default now()
);
insert into public.company_profile (id) values (1) on conflict (id) do nothing;

drop trigger if exists trg_company_profile_updated_at on public.company_profile;
create trigger trg_company_profile_updated_at before update on public.company_profile
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 2. 거래처 (수신처)
-- ---------------------------------------------------------------------
create table if not exists public.customers (
  id              bigint generated always as identity primary key,
  company_name    text not null,       -- 상호 (세운기계 주식회사)
  contact_name    text,                -- 담당자 (윤택수)
  contact_title   text,                -- 직함 (대표)
  phone           text,                -- 전화
  fax             text,                -- 팩스
  mobile          text,                -- 휴대폰
  email           text,
  address         text,
  biz_no          text,                -- 사업자등록번호
  memo            text,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists customers_company_idx on public.customers (company_name);

drop trigger if exists trg_customers_updated_at on public.customers;
create trigger trg_customers_updated_at before update on public.customers
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 3. 견적서 헤더
--    수신처 정보는 거래처가 나중에 바뀌어도 발행 당시 내용이 남도록 복사해 저장
-- ---------------------------------------------------------------------
create table if not exists public.quotes (
  id              bigint generated always as identity primary key,
  quote_no        text not null unique,          -- 견적 No (GK20261110-01)
  quote_date      date not null default current_date,
  delivery_term   text default '발주 후 4~6주',  -- 납기일
  project_name    text,                          -- P.J
  customer_id     bigint references public.customers(id) on delete set null,
  to_company      text,                          -- 수신 (상호)
  to_contact      text,                          -- 수신 담당자 + 직함
  to_phone        text,
  to_fax          text,
  to_email        text,
  to_mobile       text,
  manager_name    text,                          -- 견적담당
  manager_phone   text,                          -- 연락처
  price_tier      text not null default 'base_price'
                  check (price_tier in ('base_price','dealer_price','general_agency_price','special_agency_price')),
  vat_mode        text not null default 'excluded' check (vat_mode in ('excluded','included')),
  supply_amount   numeric(14,0) not null default 0,   -- 합계 (공급가액)
  vat_amount      numeric(14,0) not null default 0,
  total_amount    numeric(14,0) not null default 0,   -- 견적금액
  notes           text,                          -- 참고사항
  remarks         text,                          -- 특기사항
  status          text not null default 'draft' check (status in ('draft','issued','won','lost')),
  created_by      uuid default auth.uid(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
-- 이전 버전에서 만든 테이블에 수신 E-mail 컬럼 추가
alter table public.quotes add column if not exists to_email text;

create index if not exists quotes_date_idx     on public.quotes (quote_date desc);
create index if not exists quotes_customer_idx on public.quotes (customer_id);

drop trigger if exists trg_quotes_updated_at on public.quotes;
create trigger trg_quotes_updated_at before update on public.quotes
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 4. 견적 품목
-- ---------------------------------------------------------------------
create table if not exists public.quote_items (
  id              bigint generated always as identity primary key,
  quote_id        bigint not null references public.quotes(id) on delete cascade,
  line_no         int not null,
  price_list_id   bigint references public.price_list(id) on delete set null, -- 가격표 품목 (자유입력이면 NULL)
  product_name    text,           -- 품명 (유성감속기)
  product_name_en text,           -- 영문 품명 (Planetary Gearbox)
  spec            text,           -- 규격 (여러 줄)
  qty             numeric(12,2) not null default 1,
  unit            text default 'EA',
  unit_price      numeric(14,0) not null default 0,
  amount          numeric(16,0) generated always as (round(qty * unit_price)) stored,
  remark          text            -- 비고
);
create index if not exists quote_items_quote_idx on public.quote_items (quote_id, line_no);

-- ---------------------------------------------------------------------
-- 5. 견적번호 생성: 접두어 + YYYYMMDD + '-' + 일련번호 2자리
-- ---------------------------------------------------------------------
create or replace function public.next_quote_no(p_date date default current_date)
returns text language plpgsql stable as $$
declare
  v_prefix text;
  v_base   text;
  v_seq    int;
begin
  select coalesce(quote_prefix, 'GK') into v_prefix from public.company_profile where id = 1;
  v_base := coalesce(v_prefix, 'GK') || to_char(p_date, 'YYYYMMDD') || '-';
  select coalesce(max(nullif(regexp_replace(substr(quote_no, length(v_base) + 1), '\D', '', 'g'), '')::int), 0) + 1
    into v_seq
    from public.quotes
   where quote_no like v_base || '%';
  return v_base || lpad(v_seq::text, 2, '0');
end $$;

-- ---------------------------------------------------------------------
-- 6. 견적 저장 (헤더 + 품목을 한 트랜잭션으로 저장)
--    p_quote.id 가 있으면 수정, 없으면 신규. 품목은 전체 교체.
--    합계는 서버에서 다시 계산.
-- ---------------------------------------------------------------------
create or replace function public.save_quote(p_quote jsonb, p_items jsonb)
returns public.quotes
language plpgsql security invoker as $$
declare
  v_id     bigint := nullif(p_quote->>'id', '')::bigint;
  v_date   date   := coalesce(nullif(p_quote->>'quote_date', '')::date, current_date);
  v_no     text   := nullif(trim(p_quote->>'quote_no'), '');
  v_supply numeric;
  v_vat    numeric;
  v_row    public.quotes;
begin
  if v_no is null then v_no := public.next_quote_no(v_date); end if;

  select coalesce(sum(round(coalesce(nullif(i->>'qty','')::numeric, 0) *
                            coalesce(nullif(i->>'unit_price','')::numeric, 0))), 0)
    into v_supply
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) i;
  v_vat := case when p_quote->>'vat_mode' = 'included' then round(v_supply * 0.1) else 0 end;

  if v_id is null then
    insert into public.quotes (quote_no, quote_date) values (v_no, v_date) returning id into v_id;
  end if;

  update public.quotes set
    quote_no      = v_no,
    quote_date    = v_date,
    delivery_term = p_quote->>'delivery_term',
    project_name  = p_quote->>'project_name',
    customer_id   = nullif(p_quote->>'customer_id', '')::bigint,
    to_company    = p_quote->>'to_company',
    to_contact    = p_quote->>'to_contact',
    to_phone      = p_quote->>'to_phone',
    to_fax        = p_quote->>'to_fax',
    to_email      = p_quote->>'to_email',
    to_mobile     = p_quote->>'to_mobile',
    manager_name  = p_quote->>'manager_name',
    manager_phone = p_quote->>'manager_phone',
    price_tier    = coalesce(nullif(p_quote->>'price_tier', ''), 'base_price'),
    vat_mode      = coalesce(nullif(p_quote->>'vat_mode', ''), 'excluded'),
    supply_amount = v_supply,
    vat_amount    = v_vat,
    total_amount  = v_supply + v_vat,
    notes         = p_quote->>'notes',
    remarks       = p_quote->>'remarks',
    status        = coalesce(nullif(p_quote->>'status', ''), 'draft')
  where id = v_id;

  if not found then raise exception '견적서(id=%)를 찾을 수 없거나 권한이 없습니다.', v_id; end if;

  delete from public.quote_items where quote_id = v_id;
  insert into public.quote_items
    (quote_id, line_no, price_list_id, product_name, product_name_en, spec, qty, unit, unit_price, remark)
  select v_id, row_number() over (order by ord),
         nullif(i->>'price_list_id', '')::bigint,
         i->>'product_name', i->>'product_name_en', i->>'spec',
         coalesce(nullif(i->>'qty', '')::numeric, 0),
         coalesce(nullif(i->>'unit', ''), 'EA'),
         coalesce(nullif(i->>'unit_price', '')::numeric, 0),
         i->>'remark'
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) with ordinality as t(i, ord);

  select * into v_row from public.quotes where id = v_id;
  return v_row;
end $$;

-- ---------------------------------------------------------------------
-- 7. RLS: 로그인한 사용자(사내 계정)만 조회·작성 가능
--    (Supabase Auth > Users 에서 직원 계정을 만들어 사용)
-- ---------------------------------------------------------------------
alter table public.company_profile enable row level security;
alter table public.customers       enable row level security;
alter table public.quotes          enable row level security;
alter table public.quote_items     enable row level security;

drop policy if exists "auth all" on public.company_profile;
create policy "auth all" on public.company_profile for all to authenticated using (true) with check (true);
drop policy if exists "auth all" on public.customers;
create policy "auth all" on public.customers       for all to authenticated using (true) with check (true);
drop policy if exists "auth all" on public.quotes;
create policy "auth all" on public.quotes          for all to authenticated using (true) with check (true);
drop policy if exists "auth all" on public.quote_items;
create policy "auth all" on public.quote_items     for all to authenticated using (true) with check (true);

grant execute on function public.next_quote_no(date)      to authenticated;
grant execute on function public.save_quote(jsonb, jsonb) to authenticated;

-- 예시 거래처 (첨부 견적서 기준, 필요 없으면 삭제)
insert into public.customers (company_name, contact_name, contact_title, phone, fax, mobile)
select '세운기계 주식회사', '윤택수', '대표', '032)665-2496', '032)666-9640', '010-9183-2496'
where not exists (select 1 from public.customers where company_name = '세운기계 주식회사');
