-- =====================================================================
--  LIVRARIA INSPIRE — PRESENCE
--  Estrutura completa do banco de dados (Supabase / PostgreSQL)
--  Versao 2.0
--
--  COMO USAR: cole este arquivo inteiro no SQL Editor do Supabase
--  e clique em RUN. Pode rodar mais de uma vez sem quebrar nada.
--
--  Caminho do pedido:
--    Na fila -> Em atendimento -> Enviado -> Finalizado
--    Desvios: Em espera (falta produto) e Cancelado
-- =====================================================================

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

-- ---------------------------------------------------------------------
-- 1. TIPOS
-- ---------------------------------------------------------------------
do $$ begin create type user_role    as enum ('admin','atendente','igreja','ponto');
exception when duplicate_object then null; end $$;

do $$ begin create type user_status  as enum ('pendente','aprovado','rejeitado','inativo');
exception when duplicate_object then null; end $$;

do $$ begin create type unit_type    as enum ('igreja','ponto');
exception when duplicate_object then null; end $$;

do $$ begin create type product_type as enum ('livro','item');
exception when duplicate_object then null; end $$;

do $$ begin create type visibility   as enum ('igreja','ponto','ambos');
exception when duplicate_object then null; end $$;

do $$ begin create type order_status as enum
  ('fila','em_atendimento','em_espera','enviado','finalizado','cancelado');
exception when duplicate_object then null; end $$;

-- garante as situacoes novas caso o tipo ja existisse da versao 1
alter type order_status add value if not exists 'em_espera';
alter type order_status add value if not exists 'finalizado';


-- ---------------------------------------------------------------------
-- 2. TABELAS
-- ---------------------------------------------------------------------

-- 2.1 Unidades
create table if not exists public.units (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  type        unit_type not null,
  responsible text,
  phone       text,
  city        text,
  state       text,
  address     text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index if not exists units_type_idx on public.units(type);

-- 2.2 Perfis
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '',
  email       text not null default '',
  whatsapp    text not null default '',
  role        user_role,
  unit_id     uuid references public.units(id) on delete set null,
  status      user_status not null default 'pendente',
  created_at  timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  note        text
);
create index if not exists profiles_status_idx on public.profiles(status);
create index if not exists profiles_unit_idx   on public.profiles(unit_id);

-- 2.3 Catalogo
create table if not exists public.products (
  id          uuid primary key default gen_random_uuid(),
  type        product_type not null default 'livro',
  title       text not null,
  author      text,
  edition     text,
  summary     text,
  photo_url   text,
  visibility  visibility not null default 'ambos',
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users(id) on delete set null,
  search_text text generated always as (
    lower(coalesce(title,'')||' '||coalesce(author,'')||' '||
          coalesce(edition,'')||' '||coalesce(summary,''))
  ) stored
);
create index if not exists products_search_idx on public.products using gin (search_text gin_trgm_ops);
create index if not exists products_vis_idx    on public.products(visibility) where active;

-- 2.4 Pedidos
create table if not exists public.orders (
  id                 uuid primary key default gen_random_uuid(),
  code               text unique,
  unit_id            uuid not null references public.units(id) on delete restrict,
  unit_name          text not null default '',
  requested_by       uuid references auth.users(id) on delete set null,
  requested_by_name  text not null default '',
  attendant_id       uuid references auth.users(id) on delete set null,
  attendant_name     text,
  status             order_status not null default 'fila',
  note               text,
  cancel_reason      text,
  parent_order_id    uuid references public.orders(id) on delete set null,
  parent_code        text,
  waiting_note       text,
  pickup_expected    date,
  received_at        timestamptz,
  received_by        uuid references auth.users(id) on delete set null,
  received_by_name   text,
  last_message_at    timestamptz,
  created_at         timestamptz not null default now(),
  claimed_at         timestamptz,
  completed_at       timestamptz,
  canceled_at        timestamptz
);

-- colunas adicionadas na versao 2 (caso a tabela ja exista)
alter table public.orders add column if not exists parent_order_id  uuid references public.orders(id) on delete set null;
alter table public.orders add column if not exists parent_code      text;
alter table public.orders add column if not exists waiting_note     text;
alter table public.orders add column if not exists pickup_expected  date;
alter table public.orders add column if not exists received_at      timestamptz;
alter table public.orders add column if not exists received_by      uuid references auth.users(id) on delete set null;
alter table public.orders add column if not exists received_by_name text;
alter table public.orders add column if not exists last_message_at  timestamptz;

create index if not exists orders_status_idx on public.orders(status);
create index if not exists orders_unit_idx   on public.orders(unit_id);
create index if not exists orders_att_idx    on public.orders(attendant_id);
create index if not exists orders_parent_idx on public.orders(parent_order_id);

create table if not exists public.order_items (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.orders(id) on delete cascade,
  product_id      uuid not null references public.products(id) on delete restrict,
  product_title   text not null default '',
  qty_requested   integer not null check (qty_requested > 0),
  qty_sent        integer not null default 0 check (qty_sent >= 0),
  removed         boolean not null default false,
  removed_at      timestamptz,
  removed_by      uuid references auth.users(id) on delete set null,
  removed_by_name text,
  removed_reason  text
);
alter table public.order_items add column if not exists removed         boolean not null default false;
alter table public.order_items add column if not exists removed_at      timestamptz;
alter table public.order_items add column if not exists removed_by      uuid references auth.users(id) on delete set null;
alter table public.order_items add column if not exists removed_by_name text;
alter table public.order_items add column if not exists removed_reason  text;
create index if not exists order_items_order_idx on public.order_items(order_id);

-- 2.5 Conversa do pedido
create table if not exists public.order_messages (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references public.orders(id) on delete cascade,
  author_id   uuid references auth.users(id) on delete set null,
  author_name text not null default '',
  author_role user_role,
  body        text not null,
  is_system   boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists order_messages_idx on public.order_messages(order_id, created_at);

-- 2.6 Estoque por unidade
create table if not exists public.stock (
  unit_id    uuid not null references public.units(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  qty        integer not null default 0 check (qty >= 0),
  updated_at timestamptz not null default now(),
  primary key (unit_id, product_id)
);

-- 2.7 Vendas
create table if not exists public.sales (
  id              uuid primary key default gen_random_uuid(),
  code            text unique,
  unit_id         uuid not null references public.units(id) on delete restrict,
  unit_name       text not null default '',
  created_by      uuid references auth.users(id) on delete set null,
  created_by_name text not null default '',
  total           numeric(12,2) not null default 0,
  receipt_path    text,
  note            text,
  created_at      timestamptz not null default now()
);
create index if not exists sales_unit_idx on public.sales(unit_id);
create index if not exists sales_date_idx on public.sales(created_at);

create table if not exists public.sale_items (
  id            uuid primary key default gen_random_uuid(),
  sale_id       uuid not null references public.sales(id) on delete cascade,
  product_id    uuid not null references public.products(id) on delete restrict,
  product_title text not null default '',
  qty           integer not null check (qty > 0),
  unit_price    numeric(12,2) not null default 0,
  subtotal      numeric(12,2) not null default 0
);
create index if not exists sale_items_sale_idx on public.sale_items(sale_id);

-- 2.8 Registro de acoes
create table if not exists public.activity_log (
  id         bigserial primary key,
  actor_id   uuid references auth.users(id) on delete set null,
  actor_name text,
  action     text not null,
  entity     text,
  entity_id  uuid,
  details    jsonb,
  created_at timestamptz not null default now()
);
create index if not exists log_date_idx   on public.activity_log(created_at desc);
create index if not exists log_entity_idx on public.activity_log(entity, entity_id);

-- 2.9 Avisos
create table if not exists public.notifications (
  id             uuid primary key default gen_random_uuid(),
  target_user_id uuid references auth.users(id) on delete cascade,
  target_unit_id uuid references public.units(id) on delete cascade,
  target_role    user_role,
  title          text not null,
  body           text,
  kind           text not null default 'geral',
  order_id       uuid references public.orders(id) on delete cascade,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now()
);
create index if not exists notif_user_idx on public.notifications(target_user_id);
create index if not exists notif_unit_idx on public.notifications(target_unit_id);
create index if not exists notif_role_idx on public.notifications(target_role);
create index if not exists notif_date_idx on public.notifications(created_at desc);

create table if not exists public.notification_reads (
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (notification_id, user_id)
);

-- 2.11 Codigos de e-mail (cadastro e recuperacao de senha, via Brevo)
create table if not exists public.email_codes (
  id         uuid primary key default gen_random_uuid(),
  email      text not null,
  purpose    text not null,
  code_hash  text not null,
  expires_at timestamptz not null,
  attempts   integer not null default 0,
  used_at    timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists email_codes_busca_idx
  on public.email_codes (email, purpose, created_at desc);

-- 2.13 Maquininhas de cada filial (integracao Stone)
create table if not exists public.unit_devices (
  id         uuid primary key default gen_random_uuid(),
  unit_id    uuid not null references public.units(id) on delete cascade,
  serial     text not null,
  nickname   text,
  active     boolean not null default true,
  note       text,
  created_at timestamptz not null default now()
);
create unique index if not exists unit_devices_serial_unico
  on public.unit_devices (upper(trim(serial)));
create index if not exists unit_devices_unit_idx on public.unit_devices(unit_id);

-- 2.14 Configuracoes gerais da rede
create table if not exists public.settings (
  key        text primary key,
  value      text,
  updated_at timestamptz not null default now()
);
insert into public.settings (key, value) values
  ('stone_code', null), ('stone_cnpj', null), ('stone_ativo', 'false')
on conflict (key) do nothing;

-- 2.15 Sequencias
create sequence if not exists public.order_code_seq start 1;
create sequence if not exists public.sale_code_seq  start 1;


-- ---------------------------------------------------------------------
-- 3. FUNCOES AUXILIARES
-- ---------------------------------------------------------------------
create or replace function public.my_role() returns user_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and status = 'aprovado';
$$;

create or replace function public.my_unit() returns uuid
language sql stable security definer set search_path = public as $$
  select unit_id from public.profiles where id = auth.uid() and status = 'aprovado';
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles
                where id = auth.uid() and role = 'admin' and status = 'aprovado');
$$;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles
                where id = auth.uid() and role in ('admin','atendente') and status = 'aprovado');
$$;

create or replace function public.my_name() returns text
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(full_name,''), email) from public.profiles where id = auth.uid();
$$;

create or replace function public.log_action(
  p_action text, p_entity text, p_entity_id uuid, p_details jsonb default '{}'::jsonb
) returns void
language sql security definer set search_path = public as $$
  insert into public.activity_log(actor_id, actor_name, action, entity, entity_id, details)
  values (auth.uid(), public.my_name(), p_action, p_entity, p_entity_id, p_details);
$$;

create or replace function public.fn_notify(
  p_user uuid, p_unit uuid, p_role user_role,
  p_title text, p_body text, p_kind text, p_order uuid
) returns void
language sql security definer set search_path = public as $$
  insert into public.notifications
    (target_user_id, target_unit_id, target_role, title, body, kind, order_id, created_by)
  values (p_user, p_unit, p_role, p_title, p_body, p_kind, p_order, auth.uid());
$$;

create or replace function public.msg_sistema(p_order uuid, p_texto text) returns void
language sql security definer set search_path = public as $$
  insert into public.order_messages (order_id, author_id, author_name, author_role, body, is_system)
  values (p_order, auth.uid(), public.my_name(), public.my_role(), p_texto, true);
$$;


-- ---------------------------------------------------------------------
-- 4. CRIACAO AUTOMATICA DO PERFIL
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_admin boolean;
begin
  v_admin := lower(new.email) = 'livraria.app@livrariainspire.com.br';

  insert into public.profiles (id, full_name, email, whatsapp, role, status, approved_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    new.email,
    coalesce(new.raw_user_meta_data->>'whatsapp',''),
    case when v_admin then 'admin'::user_role else null end,
    case when v_admin then 'aprovado'::user_status else 'pendente'::user_status end,
    case when v_admin then now() else null end
  )
  on conflict (id) do nothing;

  if not v_admin then
    insert into public.notifications (target_role, title, body, kind)
    values ('admin', 'Novo cadastro para aprovar',
            coalesce(nullif(new.raw_user_meta_data->>'full_name',''), new.email)
              || ' pediu acesso ao sistema.', 'cadastro');
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------
-- 5. REGRAS DE NEGOCIO (RPC)
-- ---------------------------------------------------------------------

-- 5.1 Aprovar cadastro
create or replace function public.fn_approve_user(
  p_user uuid, p_role user_role, p_unit uuid default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Apenas o administrador pode aprovar cadastros.'; end if;
  if p_role in ('igreja','ponto') and p_unit is null then
    raise exception 'Selecione a filial para este perfil.'; end if;
  if p_role in ('igreja','ponto') and not exists (
    select 1 from public.units u where u.id = p_unit and u.type::text = p_role::text) then
    raise exception 'A filial escolhida não corresponde ao perfil selecionado.'; end if;

  update public.profiles
     set role = p_role,
         unit_id = case when p_role in ('igreja','ponto') then p_unit else null end,
         status = 'aprovado', approved_at = now(), approved_by = auth.uid()
   where id = p_user;

  perform public.fn_notify(p_user, null, null, 'Seu acesso foi liberado',
    'Você já pode usar o sistema Order Book da Livraria Inspire.', 'acesso', null);
  perform public.log_action('usuario_aprovado','profiles',p_user,
    jsonb_build_object('role',p_role,'unit_id',p_unit));
end $$;

-- 5.2 Recusar / desativar
create or replace function public.fn_set_user_status(
  p_user uuid, p_status user_status, p_note text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Apenas o administrador pode alterar cadastros.'; end if;
  update public.profiles set status = p_status, note = p_note where id = p_user;
  perform public.log_action('usuario_status','profiles',p_user,
    jsonb_build_object('status',p_status,'note',p_note));
end $$;

-- 5.3 Unidade cria pedido
create or replace function public.fn_create_order(
  p_items jsonb, p_note text default null, p_pickup date default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_order uuid; v_unit uuid; v_role user_role; v_item jsonb; v_title text;
        v_count int := 0; v_code text; v_unome text;
begin
  v_role := public.my_role(); v_unit := public.my_unit();
  if v_role not in ('igreja','ponto') then raise exception 'Apenas filiais podem criar pedidos.'; end if;
  if v_unit is null then raise exception 'Seu usuário não está vinculado a uma filial.'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Inclua ao menos um item no pedido.'; end if;
  if p_pickup is null then
    raise exception 'Informe a data prevista para a retirada.'; end if;

  insert into public.orders (code, unit_id, unit_name, requested_by, requested_by_name, note, pickup_expected)
  select 'PED-'||lpad(nextval('public.order_code_seq')::text,5,'0'),
         u.id, u.name, auth.uid(), public.my_name(), p_note, p_pickup
    from public.units u where u.id = v_unit
  returning id, code, unit_name into v_order, v_code, v_unome;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select title into v_title from public.products
     where id = (v_item->>'product_id')::uuid and active;
    if v_title is null then raise exception 'Produto indisponível no catálogo.'; end if;
    insert into public.order_items (order_id, product_id, product_title, qty_requested)
    values (v_order, (v_item->>'product_id')::uuid, v_title, (v_item->>'qty')::int);
    v_count := v_count + 1;
  end loop;

  perform public.fn_notify(null, null, 'atendente', 'Novo pedido na fila',
    v_code || ' de ' || v_unome || ' com ' || v_count || ' produto(s). Retirada prevista para '
      || to_char(p_pickup, 'DD/MM/YYYY') || '.', 'pedido', v_order);
  perform public.log_action('pedido_criado','orders',v_order,
    jsonb_build_object('itens',v_count,'retirada_prevista',p_pickup));
  return v_order;
end $$;

-- 5.4 Atendente puxa da fila
create or replace function public.fn_claim_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_rows int; v_unit uuid; v_code text;
begin
  if public.my_role() not in ('atendente','admin') then
    raise exception 'Apenas atendentes podem puxar pedidos.'; end if;

  update public.orders
     set status='em_atendimento', attendant_id=auth.uid(),
         attendant_name=public.my_name(), claimed_at=now()
   where id=p_order and status='fila'
  returning unit_id, code into v_unit, v_code;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then raise exception 'Este pedido já foi puxado por outro atendente.'; end if;

  perform public.msg_sistema(p_order, public.my_name() || ' assumiu o atendimento deste pedido.');
  perform public.fn_notify(null, v_unit, null, 'Pedido em atendimento',
    v_code || ' foi assumido por ' || public.my_name() || '.', 'pedido', p_order);
  perform public.log_action('pedido_puxado','orders',p_order,'{}'::jsonb);
end $$;

-- 5.5 Devolver para a fila
create or replace function public.fn_release_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_rows int;
begin
  if not public.is_staff() then raise exception 'Sem permissão.'; end if;
  update public.orders
     set status='fila', attendant_id=null, attendant_name=null, claimed_at=null
   where id=p_order and status in ('em_atendimento','em_espera')
     and (attendant_id = auth.uid() or public.is_admin());
  get diagnostics v_rows = row_count;
  if v_rows = 0 then raise exception 'Não foi possível devolver este pedido.'; end if;

  perform public.msg_sistema(p_order, public.my_name() || ' devolveu o pedido para a fila.');
  perform public.fn_notify(null, null, 'atendente', 'Pedido de volta na fila',
    'Um pedido voltou para a fila e precisa de atendente.', 'pedido', p_order);
  perform public.log_action('pedido_devolvido','orders',p_order,'{}'::jsonb);
end $$;

-- 5.6 Admin redireciona
create or replace function public.fn_reassign_order(p_order uuid, p_attendant uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_name text; v_code text;
begin
  if not public.is_admin() then raise exception 'Apenas o administrador pode redirecionar pedidos.'; end if;
  select coalesce(nullif(full_name,''), email) into v_name from public.profiles
   where id=p_attendant and role='atendente' and status='aprovado';
  if v_name is null then raise exception 'Atendente inválido.'; end if;

  update public.orders
     set attendant_id=p_attendant, attendant_name=v_name,
         status = case when status = 'fila' then 'em_atendimento'::order_status else status end,
         claimed_at=coalesce(claimed_at, now())
   where id=p_order and status in ('fila','em_atendimento','em_espera')
  returning code into v_code;
  if v_code is null then raise exception 'Este pedido não pode ser redirecionado.'; end if;

  perform public.msg_sistema(p_order, 'A administração redirecionou este pedido para ' || v_name || '.');
  perform public.fn_notify(p_attendant, null, null, 'Pedido redirecionado para voce',
    v_code || ' passou a ser seu atendimento.', 'pedido', p_order);
  perform public.log_action('pedido_redirecionado','orders',p_order,
    jsonb_build_object('para',v_name,'atendente_id',p_attendant));
end $$;

-- 5.7 Retirar item em falta
create or replace function public.fn_remove_order_item(
  p_item uuid, p_reason text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_order uuid; v_title text; v_qty int; v_unit uuid; v_code text;
begin
  if not public.is_staff() then raise exception 'Apenas o atendimento pode retirar itens.'; end if;

  update public.order_items
     set removed = true, removed_at = now(), removed_by = auth.uid(),
         removed_by_name = public.my_name(), removed_reason = p_reason, qty_sent = 0
   where id = p_item and removed = false
  returning order_id, product_title, qty_requested into v_order, v_title, v_qty;
  if v_order is null then raise exception 'Item não encontrado ou já retirado.'; end if;

  select unit_id, code into v_unit, v_code from public.orders where id = v_order;

  perform public.msg_sistema(v_order,
    public.my_name() || ' retirou "' || v_title || '" (' || v_qty || ' un.) do pedido.' ||
    coalesce(' Motivo: ' || p_reason, ''));
  perform public.fn_notify(null, v_unit, null, 'Item retirado do pedido',
    '"' || v_title || '" foi retirado de ' || v_code || '.', 'pedido', v_order);
  perform public.log_action('item_retirado','orders',v_order,
    jsonb_build_object('produto',v_title,'quantidade',v_qty,'motivo',p_reason));
end $$;

-- 5.8 Devolver item retirado
create or replace function public.fn_restore_order_item(p_item uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_order uuid; v_title text;
begin
  if not public.is_staff() then raise exception 'Sem permissão.'; end if;
  update public.order_items
     set removed = false, removed_at = null, removed_by = null,
         removed_by_name = null, removed_reason = null
   where id = p_item and removed = true
  returning order_id, product_title into v_order, v_title;
  if v_order is null then return; end if;

  perform public.msg_sistema(v_order, public.my_name() || ' devolveu "' || v_title || '" ao pedido.');
  perform public.log_action('item_devolvido','orders',v_order, jsonb_build_object('produto',v_title));
end $$;

-- 5.9 Concluir o envio (cria o pedido em espera com o que faltou)
create or replace function public.fn_fulfill_order(
  p_order uuid, p_items jsonb,
  p_criar_espera boolean default true, p_espera_note text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_unit uuid; v_status order_status; v_item jsonb; v_qty int; v_prod uuid;
  v_code text; v_att uuid; v_espera uuid; v_espera_code text;
  v_falta int; v_enviados int := 0; r record;
begin
  if not public.is_staff() then raise exception 'Sem permissão.'; end if;
  select unit_id, status, code, attendant_id
    into v_unit, v_status, v_code, v_att
    from public.orders where id=p_order;
  if v_unit is null then raise exception 'Pedido não encontrado.'; end if;
  if v_status <> 'em_atendimento' then
    raise exception 'O pedido precisa estar em atendimento para ser enviado.'; end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := greatest(0, coalesce((v_item->>'qty_sent')::int, 0));
    v_prod := null;
    update public.order_items set qty_sent = v_qty
     where id = (v_item->>'item_id')::uuid and order_id = p_order and removed = false
    returning product_id into v_prod;

    if v_prod is not null and v_qty > 0 then
      -- so o Ponto de Partida mantem estoque no sistema
      if v_tipo = 'ponto' then
        insert into public.stock (unit_id, product_id, qty, updated_at)
        values (v_unit, v_prod, v_qty, now())
        on conflict (unit_id, product_id)
        do update set qty = public.stock.qty + excluded.qty, updated_at = now();
      end if;
      v_enviados := v_enviados + v_qty;
    end if;
  end loop;

  if v_enviados = 0 then
    raise exception 'Informe ao menos um item enviado. Se não há nada a enviar, cancele o pedido.';
  end if;

  if p_criar_espera and exists (
      select 1 from public.order_items
       where order_id = p_order and (removed or qty_sent < qty_requested)) then

    insert into public.orders (code, unit_id, unit_name, requested_by, requested_by_name,
                               attendant_id, attendant_name, status, parent_order_id, parent_code,
                               waiting_note, pickup_expected, claimed_at)
    select 'PED-'||lpad(nextval('public.order_code_seq')::text,5,'0'),
           o.unit_id, o.unit_name, o.requested_by, o.requested_by_name,
           coalesce(o.attendant_id, auth.uid()), coalesce(o.attendant_name, public.my_name()),
           'em_espera', o.id, o.code, p_espera_note, o.pickup_expected, now()
      from public.orders o where o.id = p_order
    returning id, code into v_espera, v_espera_code;

    for r in
      select product_id, product_title, qty_requested, qty_sent, removed
        from public.order_items
       where order_id = p_order and (removed or qty_sent < qty_requested)
    loop
      v_falta := case when r.removed then r.qty_requested else r.qty_requested - r.qty_sent end;
      if v_falta > 0 then
        insert into public.order_items (order_id, product_id, product_title, qty_requested)
        values (v_espera, r.product_id, r.product_title, v_falta);
      end if;
    end loop;

    perform public.msg_sistema(p_order,
      'O que faltou foi transferido para o pedido ' || v_espera_code || ', que ficou em espera.');
    perform public.msg_sistema(v_espera,
      'Pedido em espera criado a partir de ' || v_code || '.' || coalesce(' ' || p_espera_note, ''));
    perform public.fn_notify(null, v_unit, null, 'Pedido em espera',
      v_espera_code || ' guarda o que faltou de ' || v_code || '.', 'pedido', v_espera);
    perform public.fn_notify(coalesce(v_att, auth.uid()), null, null, 'Pedido em espera com você',
      v_espera_code || ' aguarda a chegada do produto.', 'pedido', v_espera);
  end if;

  update public.orders set status='enviado', completed_at=now() where id=p_order;

  perform public.msg_sistema(p_order,
    public.my_name() || ' registrou o envio. Confirme o recebimento para finalizar o pedido.');
  perform public.fn_notify(null, v_unit, null, 'Confirme o recebimento',
    v_code || ' foi enviado. Confirme o recebimento para finalizar.', 'recebimento', p_order);
  perform public.log_action('pedido_enviado','orders',p_order,
    jsonb_build_object('itens_enviados',v_enviados,'pedido_espera',v_espera_code));
  return v_espera;
end $$;

-- 5.10 Unidade confirma o recebimento
create or replace function public.fn_confirm_receipt(p_order uuid, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_unit uuid; v_code text; v_att uuid; v_rows int;
begin
  select unit_id, code, attendant_id into v_unit, v_code, v_att from public.orders where id = p_order;
  if v_unit is null then raise exception 'Pedido não encontrado.'; end if;
  if not ((public.my_unit() = v_unit and public.my_role() in ('igreja','ponto')) or public.is_admin()) then
    raise exception 'Apenas a filial do pedido pode confirmar o recebimento.'; end if;

  update public.orders
     set status = 'finalizado', received_at = now(),
         received_by = auth.uid(), received_by_name = public.my_name()
   where id = p_order and status = 'enviado';
  get diagnostics v_rows = row_count;
  if v_rows = 0 then raise exception 'Este pedido não está aguardando confirmação.'; end if;

  perform public.msg_sistema(p_order,
    public.my_name() || ' confirmou o recebimento. Pedido finalizado.' || coalesce(' ' || p_note, ''));
  if v_att is not null then
    perform public.fn_notify(v_att, null, null, 'Recebimento confirmado',
      v_code || ' foi recebido pela filial e está finalizado.', 'pedido', p_order);
  end if;
  perform public.log_action('pedido_recebido','orders',p_order, jsonb_build_object('observacao',p_note));
end $$;

-- 5.11 Retomar pedido em espera
create or replace function public.fn_resume_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_unit uuid; v_code text;
begin
  if not public.is_staff() then raise exception 'Apenas o atendimento pode retomar pedidos.'; end if;

  update public.orders
     set status='em_atendimento', attendant_id=coalesce(attendant_id, auth.uid()),
         attendant_name=coalesce(attendant_name, public.my_name()),
         claimed_at=coalesce(claimed_at, now())
   where id=p_order and status='em_espera'
  returning unit_id, code into v_unit, v_code;
  if v_code is null then raise exception 'Este pedido não está em espera.'; end if;

  perform public.msg_sistema(p_order, public.my_name() || ' retomou o pedido. O produto chegou.');
  perform public.fn_notify(null, v_unit, null, 'Pedido retomado',
    v_code || ' saiu da espera e voltou para o atendimento.', 'pedido', p_order);
  perform public.log_action('pedido_retomado','orders',p_order,'{}'::jsonb);
end $$;

-- 5.12 Cancelar pedido
create or replace function public.fn_cancel_order(p_order uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_unit uuid; v_code text; v_att uuid; v_rows int;
begin
  select unit_id, code, attendant_id into v_unit, v_code, v_att from public.orders where id=p_order;
  if v_unit is null then raise exception 'Pedido não encontrado.'; end if;
  if not (public.is_staff() or (public.my_unit() = v_unit and public.my_role() in ('igreja','ponto'))) then
    raise exception 'Sem permissão para cancelar este pedido.'; end if;

  update public.orders set status='cancelado', cancel_reason=p_reason, canceled_at=now()
   where id=p_order and status in ('fila','em_atendimento','em_espera');
  get diagnostics v_rows = row_count;
  if v_rows = 0 then raise exception 'Este pedido não pode mais ser cancelado.'; end if;

  perform public.msg_sistema(p_order,
    public.my_name() || ' cancelou o pedido.' || coalesce(' Motivo: ' || p_reason, ''));
  if public.is_staff() then
    perform public.fn_notify(null, v_unit, null, 'Pedido cancelado', v_code || ' foi cancelado.', 'pedido', p_order);
  elsif v_att is not null then
    perform public.fn_notify(v_att, null, null, 'Pedido cancelado pela unidade',
      v_code || ' foi cancelado.', 'pedido', p_order);
  end if;
  perform public.log_action('pedido_cancelado','orders',p_order, jsonb_build_object('motivo',p_reason));
end $$;

-- 5.13 Conversa do pedido
create or replace function public.fn_send_message(p_order uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_unit uuid; v_att uuid; v_code text; v_msg uuid; v_role user_role;
begin
  if p_body is null or length(trim(p_body)) = 0 then raise exception 'Escreva uma mensagem.'; end if;
  select unit_id, attendant_id, code into v_unit, v_att, v_code from public.orders where id = p_order;
  if v_unit is null then raise exception 'Pedido não encontrado.'; end if;

  v_role := public.my_role();
  if not (public.is_staff() or public.my_unit() = v_unit) then
    raise exception 'Sem permissão para conversar neste pedido.'; end if;

  insert into public.order_messages (order_id, author_id, author_name, author_role, body)
  values (p_order, auth.uid(), public.my_name(), v_role, trim(p_body))
  returning id into v_msg;

  update public.orders set last_message_at = now() where id = p_order;

  if v_role in ('igreja','ponto') then
    if v_att is not null then
      perform public.fn_notify(v_att, null, null, 'Nova mensagem no pedido',
        v_code || ': ' || left(trim(p_body), 90), 'mensagem', p_order);
    else
      perform public.fn_notify(null, null, 'atendente', 'Nova mensagem no pedido',
        v_code || ': ' || left(trim(p_body), 90), 'mensagem', p_order);
    end if;
  else
    perform public.fn_notify(null, v_unit, null, 'Nova mensagem no pedido',
      v_code || ': ' || left(trim(p_body), 90), 'mensagem', p_order);
  end if;
  return v_msg;
end $$;

-- 5.14 Avisos nao lidos
create or replace function public.fn_my_notifications()
returns table (id uuid, title text, body text, kind text, order_id uuid, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select n.id, n.title, n.body, n.kind, n.order_id, n.created_at
    from public.notifications n
   where (n.target_user_id = auth.uid()
          or (n.target_unit_id is not null and n.target_unit_id = public.my_unit())
          or (n.target_role   is not null and n.target_role   = public.my_role()))
     and (n.created_by is null or n.created_by <> auth.uid())
     and not exists (select 1 from public.notification_reads r
                      where r.notification_id = n.id and r.user_id = auth.uid())
   order by n.created_at desc
   limit 50;
$$;

-- 5.15 Marcar avisos como lidos
create or replace function public.fn_read_notifications(p_ids uuid[]) returns void
language sql security definer set search_path = public as $$
  insert into public.notification_reads (notification_id, user_id)
  select unnest(p_ids), auth.uid()
  on conflict do nothing;
$$;

-- 5.16 Venda da unidade
create or replace function public.fn_create_sale(
  p_items jsonb, p_receipt text default null, p_note text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_sale uuid; v_unit uuid; v_item jsonb; v_qty int; v_price numeric;
  v_prod uuid; v_title text; v_have int; v_total numeric := 0;
begin
  if public.my_role() = 'igreja' then
    raise exception 'A Igreja da Rede não registra vendas. O pedido encerra na confirmação do recebimento.';
  end if;
  if public.my_role() <> 'ponto' then
    raise exception 'Apenas o Ponto de Partida registra vendas.';
  end if;
  v_unit := public.my_unit();
  if v_unit is null then raise exception 'Seu usuário não está vinculado a uma filial.'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Inclua ao menos um item na venda.'; end if;

  insert into public.sales (code, unit_id, unit_name, created_by, created_by_name, receipt_path, note)
  select 'VEN-'||lpad(nextval('public.sale_code_seq')::text,5,'0'),
         u.id, u.name, auth.uid(), public.my_name(), p_receipt, p_note
    from public.units u where u.id = v_unit
  returning id into v_sale;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_prod  := (v_item->>'product_id')::uuid;
    v_qty   := (v_item->>'qty')::int;
    v_price := coalesce((v_item->>'unit_price')::numeric, 0);

    select title into v_title from public.products where id = v_prod;
    select qty into v_have from public.stock where unit_id=v_unit and product_id=v_prod;
    if coalesce(v_have,0) < v_qty then
      raise exception 'Estoque insuficiente de "%": você tem % e tentou vender %.',
        coalesce(v_title,'produto'), coalesce(v_have,0), v_qty;
    end if;

    update public.stock set qty = qty - v_qty, updated_at=now()
     where unit_id=v_unit and product_id=v_prod;

    insert into public.sale_items (sale_id, product_id, product_title, qty, unit_price, subtotal)
    values (v_sale, v_prod, coalesce(v_title,''), v_qty, v_price, v_qty*v_price);
    v_total := v_total + (v_qty * v_price);
  end loop;

  update public.sales set total = v_total where id = v_sale;
  perform public.log_action('venda_registrada','sales',v_sale, jsonb_build_object('total',v_total));
  return v_sale;
end $$;

-- 5.16b Entregas ja feitas a uma filial (usado pela Igreja da Rede)
create or replace function public.fn_entregas_filial(p_unit uuid default null)
returns table (
  product_id uuid, product_title text, product_type product_type,
  photo_url text, author text, edition text,
  total_recebido bigint, ultima_entrega timestamptz
)
language sql stable security definer set search_path = public as $$
  select p.id, p.title, p.type, p.photo_url, p.author, p.edition,
         sum(i.qty_sent)::bigint, max(o.completed_at)
    from public.order_items i
    join public.orders o   on o.id = i.order_id
    join public.products p on p.id = i.product_id
   where i.qty_sent > 0
     and o.status in ('enviado','finalizado')
     and o.unit_id = coalesce(p_unit, public.my_unit())
     and (public.is_staff() or o.unit_id = public.my_unit())
   group by p.id, p.title, p.type, p.photo_url, p.author, p.edition
   order by p.title;
$$;

-- 5.17 Relatorios
create or replace function public.fn_report_sales(
  p_from date default null, p_to date default null
) returns table (
  unit_id uuid, unit_name text, unit_type unit_type,
  vendas bigint, itens bigint, total numeric
)
language sql stable security definer set search_path = public as $$
  select u.id, u.name, u.type,
         count(distinct s.id), coalesce(sum(si.qty),0), coalesce(sum(si.subtotal),0)
    from public.units u
    left join public.sales s on s.unit_id = u.id
      and (p_from is null or s.created_at >= p_from)
      and (p_to   is null or s.created_at < (p_to + 1))
    left join public.sale_items si on si.sale_id = s.id
   where public.is_staff()
   group by u.id, u.name, u.type
   order by 6 desc, 2;
$$;

create or replace function public.fn_report_stock()
returns table (
  unit_id uuid, unit_name text, unit_type unit_type,
  product_id uuid, product_title text, product_type product_type, qty integer
)
language sql stable security definer set search_path = public as $$
  select u.id, u.name, u.type, p.id, p.title, p.type, st.qty
    from public.stock st
    join public.units u    on u.id = st.unit_id
    join public.products p on p.id = st.product_id
   where public.is_staff() and st.qty > 0
   order by u.name, p.title;
$$;


-- ---------------------------------------------------------------------
-- 7. Exclusao de cadastros
--    Só apaga o que nunca foi usado. O que ja tem historico deve ser
--    desativado, para nao deixar pedidos e vendas sem referencia.
-- ---------------------------------------------------------------------

-- 7.1 Excluir produto do catalogo
create or replace function public.fn_delete_product(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_title text; v_pedidos int; v_vendas int; v_estoque int;
begin
  if not public.is_admin() then raise exception 'Apenas o administrador pode excluir produtos.'; end if;

  select title into v_title from public.products where id = p_id;
  if v_title is null then raise exception 'Produto não encontrado.'; end if;

  select count(*) into v_pedidos from public.order_items where product_id = p_id;
  select count(*) into v_vendas  from public.sale_items  where product_id = p_id;
  select count(*) into v_estoque from public.stock       where product_id = p_id and qty > 0;

  if v_pedidos > 0 or v_vendas > 0 or v_estoque > 0 then
    raise exception 'Não dá para excluir "%": já aparece em % pedido(s), % venda(s) e % filial(is) com estoque. Desative o produto para tirá-lo da lista sem perder o histórico.',
      v_title, v_pedidos, v_vendas, v_estoque;
  end if;

  delete from public.stock where product_id = p_id;
  delete from public.products where id = p_id;

  perform public.log_action('produto_excluido','products',p_id, jsonb_build_object('titulo',v_title));
end $$;

-- 7.2 Excluir unidade
create or replace function public.fn_delete_unit(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_name text; v_pessoas int; v_pedidos int; v_vendas int; v_estoque int;
begin
  if not public.is_admin() then raise exception 'Apenas o administrador pode excluir filiais.'; end if;

  select name into v_name from public.units where id = p_id;
  if v_name is null then raise exception 'Filial não encontrada.'; end if;

  select count(*) into v_pessoas from public.profiles where unit_id = p_id;
  select count(*) into v_pedidos from public.orders   where unit_id = p_id;
  select count(*) into v_vendas  from public.sales    where unit_id = p_id;
  select count(*) into v_estoque from public.stock    where unit_id = p_id and qty > 0;

  if v_pedidos > 0 or v_vendas > 0 or v_estoque > 0 then
    raise exception 'Não dá para excluir "%": tem % pedido(s), % venda(s) e % produto(s) em estoque. Desative a filial para tirá-la de uso sem perder o histórico.',
      v_name, v_pedidos, v_vendas, v_estoque;
  end if;

  if v_pessoas > 0 then
    raise exception 'Não dá para excluir "%": ainda há % usuário(s) vinculado(s). Troque a filial dessas pessoas ou exclua os usuários antes.',
      v_name, v_pessoas;
  end if;

  delete from public.stock where unit_id = p_id;
  delete from public.units where id = p_id;

  perform public.log_action('unidade_excluida','units',p_id, jsonb_build_object('nome',v_name));
end $$;

-- 7.3 Verificacao antes de excluir um usuario
create or replace function public.fn_check_user_delete(p_id uuid)
returns table (nome text, pedidos bigint, vendas bigint, atendimentos bigint)
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(p.full_name,''), p.email),
         (select count(*) from public.orders where requested_by = p_id),
         (select count(*) from public.sales  where created_by   = p_id),
         (select count(*) from public.orders where attendant_id = p_id)
    from public.profiles p
   where p.id = p_id and public.is_admin();
$$;

grant execute on function
  public.fn_delete_product(uuid),
  public.fn_delete_unit(uuid),
  public.fn_check_user_delete(uuid)
to authenticated;


-- 5.18 Maquininhas e configuracoes
create or replace function public.fn_save_device(
  p_id uuid, p_unit uuid, p_serial text,
  p_nickname text default null, p_active boolean default true, p_note text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_serial text; v_id uuid; v_filial text;
begin
  if not public.is_admin() then
    raise exception 'Apenas o administrador pode cadastrar maquininhas.'; end if;

  v_serial := upper(trim(coalesce(p_serial, '')));
  if length(v_serial) < 4 then
    raise exception 'Informe o número de série da maquininha.'; end if;

  select name into v_filial from public.units where id = p_unit;
  if v_filial is null then raise exception 'Filial não encontrada.'; end if;

  if exists (
    select 1 from public.unit_devices d
     where upper(trim(d.serial)) = v_serial and (p_id is null or d.id <> p_id)
  ) then
    raise exception 'Esta maquininha já está cadastrada em outra filial.';
  end if;

  if p_id is null then
    insert into public.unit_devices (unit_id, serial, nickname, active, note)
    values (p_unit, v_serial, p_nickname, p_active, p_note)
    returning id into v_id;
    perform public.log_action('maquininha_cadastrada','unit_devices',v_id,
      jsonb_build_object('serial',v_serial,'filial',v_filial));
  else
    update public.unit_devices
       set unit_id = p_unit, serial = v_serial, nickname = p_nickname,
           active = p_active, note = p_note
     where id = p_id
    returning id into v_id;
    perform public.log_action('maquininha_alterada','unit_devices',v_id,
      jsonb_build_object('serial',v_serial,'filial',v_filial));
  end if;

  return v_id;
end $$;

create or replace function public.fn_delete_device(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_serial text;
begin
  if not public.is_admin() then
    raise exception 'Apenas o administrador pode excluir maquininhas.'; end if;

  delete from public.unit_devices where id = p_id returning serial into v_serial;
  if v_serial is null then raise exception 'Maquininha não encontrada.'; end if;

  perform public.log_action('maquininha_excluida','unit_devices',p_id,
    jsonb_build_object('serial',v_serial));
end $$;

create or replace function public.fn_save_setting(p_key text, p_value text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Apenas o administrador pode alterar as configurações.'; end if;

  insert into public.settings (key, value, updated_at)
  values (p_key, p_value, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();

  perform public.log_action('configuracao_alterada','settings',null,
    jsonb_build_object('campo',p_key));
end $$;


-- ---------------------------------------------------------------------
-- 6. SEGURANCA (RLS)
-- ---------------------------------------------------------------------
alter table public.units              enable row level security;
alter table public.profiles           enable row level security;
alter table public.products           enable row level security;
alter table public.orders             enable row level security;
alter table public.order_items        enable row level security;
alter table public.order_messages     enable row level security;
alter table public.stock              enable row level security;
alter table public.sales              enable row level security;
alter table public.sale_items         enable row level security;
alter table public.activity_log       enable row level security;
alter table public.notifications      enable row level security;
alter table public.notification_reads enable row level security;
alter table public.email_codes        enable row level security;
alter table public.unit_devices       enable row level security;
alter table public.settings           enable row level security;
-- email_codes fica sem politica de proposito: so a funcao api alcanca

drop policy if exists p_profiles_self on public.profiles;
create policy p_profiles_self on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());

drop policy if exists p_profiles_staff on public.profiles;
create policy p_profiles_staff on public.profiles
  for select to authenticated using (public.is_staff() and role in ('atendente','admin'));

drop policy if exists p_profiles_update_self on public.profiles;
create policy p_profiles_update_self on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists p_profiles_admin on public.profiles;
create policy p_profiles_admin on public.profiles
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists p_units_read on public.units;
create policy p_units_read on public.units for select to authenticated using (true);

drop policy if exists p_units_admin on public.units;
create policy p_units_admin on public.units
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists p_products_read on public.products;
create policy p_products_read on public.products
  for select to authenticated using (
    public.is_staff()
    or (active and (
         visibility = 'ambos'
         or (visibility = 'igreja' and public.my_role() = 'igreja')
         or (visibility = 'ponto'  and public.my_role() = 'ponto')))
  );

drop policy if exists p_products_admin on public.products;
create policy p_products_admin on public.products
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists p_orders_read on public.orders;
create policy p_orders_read on public.orders
  for select to authenticated using (public.is_staff() or unit_id = public.my_unit());

drop policy if exists p_order_items_read on public.order_items;
create policy p_order_items_read on public.order_items
  for select to authenticated using (
    exists (select 1 from public.orders o where o.id = order_id
            and (public.is_staff() or o.unit_id = public.my_unit())));

drop policy if exists p_order_messages_read on public.order_messages;
create policy p_order_messages_read on public.order_messages
  for select to authenticated using (
    exists (select 1 from public.orders o where o.id = order_id
            and (public.is_staff() or o.unit_id = public.my_unit())));

drop policy if exists p_stock_read on public.stock;
create policy p_stock_read on public.stock
  for select to authenticated using (public.is_staff() or unit_id = public.my_unit());

drop policy if exists p_sales_read on public.sales;
create policy p_sales_read on public.sales
  for select to authenticated using (public.is_staff() or unit_id = public.my_unit());

drop policy if exists p_sale_items_read on public.sale_items;
create policy p_sale_items_read on public.sale_items
  for select to authenticated using (
    exists (select 1 from public.sales s where s.id = sale_id
            and (public.is_staff() or s.unit_id = public.my_unit())));

drop policy if exists p_log_admin on public.activity_log;
create policy p_log_admin on public.activity_log
  for select to authenticated using (public.is_admin());

drop policy if exists p_notif_read on public.notifications;
create policy p_notif_read on public.notifications
  for select to authenticated using (
    target_user_id = auth.uid()
    or (target_unit_id is not null and target_unit_id = public.my_unit())
    or (target_role   is not null and target_role   = public.my_role())
    or public.is_admin());

drop policy if exists p_devices_read on public.unit_devices;
create policy p_devices_read on public.unit_devices
  for select to authenticated using (public.is_staff() or unit_id = public.my_unit());

drop policy if exists p_devices_admin on public.unit_devices;
create policy p_devices_admin on public.unit_devices
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists p_settings_read on public.settings;
create policy p_settings_read on public.settings
  for select to authenticated using (true);

drop policy if exists p_settings_admin on public.settings;
create policy p_settings_admin on public.settings
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists p_notif_reads on public.notification_reads;
create policy p_notif_reads on public.notification_reads
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());


-- ---------------------------------------------------------------------
-- 7. ARQUIVOS (Storage)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('produtos','produtos', true) on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('comprovantes','comprovantes', false) on conflict (id) do nothing;

drop policy if exists s_produtos_read on storage.objects;
create policy s_produtos_read on storage.objects for select using (bucket_id = 'produtos');

drop policy if exists s_produtos_write on storage.objects;
create policy s_produtos_write on storage.objects
  for insert to authenticated with check (bucket_id='produtos' and public.is_admin());

drop policy if exists s_produtos_del on storage.objects;
create policy s_produtos_del on storage.objects
  for delete to authenticated using (bucket_id='produtos' and public.is_admin());

drop policy if exists s_comprovantes_write on storage.objects;
create policy s_comprovantes_write on storage.objects
  for insert to authenticated with check (
    bucket_id='comprovantes' and public.my_role() in ('igreja','ponto','admin'));

drop policy if exists s_comprovantes_read on storage.objects;
create policy s_comprovantes_read on storage.objects
  for select to authenticated using (
    bucket_id='comprovantes' and (
      public.is_staff() or (storage.foldername(name))[1] = public.my_unit()::text));


-- ---------------------------------------------------------------------
-- 8. PERMISSOES DE EXECUCAO
-- ---------------------------------------------------------------------
grant execute on function
  public.fn_approve_user(uuid,user_role,uuid),
  public.fn_set_user_status(uuid,user_status,text),
  public.fn_create_order(jsonb,text,date),
  public.fn_claim_order(uuid),
  public.fn_release_order(uuid),
  public.fn_reassign_order(uuid,uuid),
  public.fn_remove_order_item(uuid,text),
  public.fn_restore_order_item(uuid),
  public.fn_fulfill_order(uuid,jsonb,boolean,text),
  public.fn_confirm_receipt(uuid,text),
  public.fn_resume_order(uuid),
  public.fn_cancel_order(uuid,text),
  public.fn_send_message(uuid,text),
  public.fn_my_notifications(),
  public.fn_read_notifications(uuid[]),
  public.fn_create_sale(jsonb,text,text),
  public.fn_entregas_filial(uuid),
  public.fn_save_device(uuid,uuid,text,text,boolean,text),
  public.fn_delete_device(uuid),
  public.fn_save_setting(text,text),
  public.fn_report_sales(date,date),
  public.fn_report_stock(),
  public.my_role(), public.my_unit(), public.is_admin(), public.is_staff()
to authenticated;

-- ---------------------------------------------------------------------
-- 9. COBRANCA NA MAQUININHA E FILA DA OMIE
-- ---------------------------------------------------------------------
-- 1. Tipos
-- ---------------------------------------------------------------------
do $$ begin create type charge_status as enum
  ('aguardando','pago','cancelado','expirado');
exception when duplicate_object then null; end $$;

do $$ begin create type charge_method as enum
  ('credito','debito','pix','voucher','dinheiro');
exception when duplicate_object then null; end $$;

do $$ begin create type queue_status as enum
  ('pendente','simulado','enviado','erro');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 2. Ligações com a Omie
-- ---------------------------------------------------------------------
alter table public.products add column if not exists omie_code text;
alter table public.units    add column if not exists omie_client_id text;
alter table public.units    add column if not exists cnpj text;

insert into public.settings (key, value) values
  ('omie_app_key',    null),
  ('omie_app_secret', null),
  ('omie_natureza',   '2.99'),
  ('omie_categoria',  '1.01.02'),
  ('omie_conta',      null),
  ('omie_etapa',      '10'),
  ('modo_simulacao',  'true')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 3. Cobranças
-- ---------------------------------------------------------------------
create table if not exists public.charges (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,
  unit_id         uuid not null references public.units(id) on delete restrict,
  unit_name       text not null default '',
  device_serial   text,
  device_nickname text,
  amount          numeric(12,2) not null check (amount > 0),
  method          charge_method not null,
  installments    integer not null default 1,
  status          charge_status not null default 'aguardando',
  items           jsonb not null,
  created_by      uuid references auth.users(id) on delete set null,
  created_by_name text not null default '',
  external_ref    text,
  note            text,
  sale_id         uuid references public.sales(id) on delete set null,
  created_at      timestamptz not null default now(),
  paid_at         timestamptz,
  canceled_at     timestamptz,
  simulada        boolean not null default true
);
create index if not exists charges_unit_idx   on public.charges(unit_id);
create index if not exists charges_status_idx on public.charges(status);
create index if not exists charges_date_idx   on public.charges(created_at desc);

-- ---------------------------------------------------------------------
-- 4. Fila da Omie
-- ---------------------------------------------------------------------
create table if not exists public.omie_queue (
  id          uuid primary key default gen_random_uuid(),
  sale_id     uuid references public.sales(id) on delete cascade,
  charge_id   uuid references public.charges(id) on delete set null,
  unit_id     uuid references public.units(id) on delete set null,
  unit_name   text,
  kind        text not null default 'pedido_venda',
  payload     jsonb not null,
  status      queue_status not null default 'pendente',
  attempts    integer not null default 0,
  last_error  text,
  response    jsonb,
  created_at  timestamptz not null default now(),
  sent_at     timestamptz
);
create index if not exists omie_queue_status_idx on public.omie_queue(status, created_at);

alter table public.sales add column if not exists charge_id uuid references public.charges(id) on delete set null;
alter table public.sales add column if not exists omie_status queue_status;

-- ---------------------------------------------------------------------
-- 5. Segurança
-- ---------------------------------------------------------------------
alter table public.charges    enable row level security;
alter table public.omie_queue enable row level security;

drop policy if exists p_charges_read on public.charges;
create policy p_charges_read on public.charges
  for select to authenticated
  using (public.is_staff() or unit_id = public.my_unit());

drop policy if exists p_omie_queue_read on public.omie_queue;
create policy p_omie_queue_read on public.omie_queue
  for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------
-- 6. Gera um código de 6 dígitos livre
-- ---------------------------------------------------------------------
create or replace function public.gerar_codigo_cobranca() returns text
language plpgsql security definer set search_path = public as $$
declare v text; i int := 0;
begin
  loop
    v := lpad((floor(random() * 1000000))::int::text, 6, '0');
    exit when not exists (select 1 from public.charges c where c.code = v and c.status = 'aguardando');
    i := i + 1;
    if i > 50 then raise exception 'Não foi possível gerar o código da cobrança.'; end if;
  end loop;
  return v;
end $$;

-- ---------------------------------------------------------------------
-- 7. Criar a cobrança
--    p_items = [{"product_id":"...","qty":2,"unit_price":49.90}, ...]
-- ---------------------------------------------------------------------
create or replace function public.fn_create_charge(
  p_items jsonb, p_method charge_method, p_installments integer default 1,
  p_device text default null, p_note text default null
) returns table (id uuid, code text, amount numeric)
language plpgsql security definer set search_path = public as $$
declare
  v_unit uuid; v_unome text; v_item jsonb; v_prod uuid; v_qty int; v_price numeric;
  v_title text; v_have int; v_total numeric := 0; v_itens jsonb := '[]'::jsonb;
  v_code text; v_id uuid; v_apelido text; v_serial text;
begin
  if public.my_role() <> 'ponto' then
    raise exception 'Apenas o Ponto de Partida registra vendas.'; end if;

  v_unit := public.my_unit();
  if v_unit is null then raise exception 'Seu usuário não está vinculado a uma filial.'; end if;
  select name into v_unome from public.units where id = v_unit;

  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Inclua ao menos um produto na venda.'; end if;

  -- a maquininha escolhida precisa ser desta filial
  if p_device is not null then
    select serial, nickname into v_serial, v_apelido
      from public.unit_devices
     where unit_id = v_unit and upper(trim(serial)) = upper(trim(p_device)) and active;
    if v_serial is null then
      raise exception 'Esta maquininha não está cadastrada na sua filial.'; end if;
  end if;

  -- confere estoque e monta o resumo
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_prod  := (v_item->>'product_id')::uuid;
    v_qty   := (v_item->>'qty')::int;
    v_price := coalesce((v_item->>'unit_price')::numeric, 0);

    if v_qty < 1 then raise exception 'Quantidade inválida.'; end if;
    if v_price <= 0 then raise exception 'Informe o valor de cada produto.'; end if;

    select title into v_title from public.products where id = v_prod;
    if v_title is null then raise exception 'Produto não encontrado.'; end if;

    select qty into v_have from public.stock where unit_id = v_unit and product_id = v_prod;
    if coalesce(v_have,0) < v_qty then
      raise exception 'Estoque insuficiente de "%": você tem % e tentou vender %.',
        v_title, coalesce(v_have,0), v_qty;
    end if;

    v_total := v_total + (v_qty * v_price);
    v_itens := v_itens || jsonb_build_object(
      'product_id', v_prod, 'title', v_title, 'qty', v_qty,
      'unit_price', v_price, 'subtotal', v_qty * v_price);
  end loop;

  v_code := public.gerar_codigo_cobranca();

  insert into public.charges (code, unit_id, unit_name, device_serial, device_nickname,
                              amount, method, installments, items,
                              created_by, created_by_name, note, simulada)
  values (v_code, v_unit, v_unome, v_serial, v_apelido,
          v_total, p_method, greatest(1, coalesce(p_installments,1)), v_itens,
          auth.uid(), public.my_name(), p_note,
          coalesce((select s.value from public.settings s where s.key='modo_simulacao'),'true') = 'true')
  returning charges.id into v_id;

  perform public.log_action('cobranca_criada','charges',v_id,
    jsonb_build_object('codigo',v_code,'valor',v_total,'meio',p_method,'maquininha',v_serial));

  return query select v_id, v_code, v_total;
end $$;

-- ---------------------------------------------------------------------
-- 8. Consultar uma cobrança pelo código (usado pela maquininha)
-- ---------------------------------------------------------------------
create or replace function public.fn_charge_by_code(p_code text)
returns table (
  id uuid, code text, unit_name text, device_serial text, device_nickname text,
  amount numeric, method charge_method, installments integer,
  status charge_status, items jsonb, created_by_name text, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select c.id, c.code, c.unit_name, c.device_serial, c.device_nickname,
         c.amount, c.method, c.installments, c.status, c.items,
         c.created_by_name, c.created_at
    from public.charges c
   where c.code = trim(p_code)
     and (public.is_staff() or c.unit_id = public.my_unit())
   order by c.created_at desc
   limit 1;
$$;

-- ---------------------------------------------------------------------
-- 9. Confirmar o pagamento
--    Registra a venda, baixa o estoque e coloca na fila da Omie.
-- ---------------------------------------------------------------------
create or replace function public.fn_confirm_charge(
  p_code text, p_external text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_ch public.charges%rowtype; v_sale uuid; v_item jsonb;
  v_prod uuid; v_qty int; v_have int; v_omie_cli text; v_cnpj text;
  v_det jsonb := '[]'::jsonb; v_omie_prod text; v_title text;
  v_natureza text; v_categoria text; v_conta text; v_etapa text; v_sim boolean;
begin
  select * into v_ch from public.charges where code = trim(p_code) and status = 'aguardando';
  if v_ch.id is null then
    raise exception 'Nenhuma cobrança em aberto com este código.'; end if;
  if not (public.is_staff() or v_ch.unit_id = public.my_unit()) then
    raise exception 'Sem permissão para confirmar esta cobrança.'; end if;

  -- registra a venda
  insert into public.sales (code, unit_id, unit_name, created_by, created_by_name,
                            total, note, charge_id, omie_status)
  values ('VEN-'||lpad(nextval('public.sale_code_seq')::text,5,'0'),
          v_ch.unit_id, v_ch.unit_name, v_ch.created_by, v_ch.created_by_name,
          v_ch.amount, v_ch.note, v_ch.id, 'pendente')
  returning id into v_sale;

  -- baixa o estoque e grava os itens
  for v_item in select * from jsonb_array_elements(v_ch.items) loop
    v_prod  := (v_item->>'product_id')::uuid;
    v_qty   := (v_item->>'qty')::int;
    v_title := v_item->>'title';

    select qty into v_have from public.stock where unit_id=v_ch.unit_id and product_id=v_prod;
    if coalesce(v_have,0) < v_qty then
      raise exception 'O estoque de "%" mudou desde a cobrança. Cancele e refaça a venda.', v_title;
    end if;

    update public.stock set qty = qty - v_qty, updated_at = now()
     where unit_id = v_ch.unit_id and product_id = v_prod;

    insert into public.sale_items (sale_id, product_id, product_title, qty, unit_price, subtotal)
    values (v_sale, v_prod, v_title, v_qty,
            (v_item->>'unit_price')::numeric, (v_item->>'subtotal')::numeric);

    select omie_code into v_omie_prod from public.products where id = v_prod;
    v_det := v_det || jsonb_build_object(
      'produto', jsonb_build_object(
        'codigo_produto_integracao', v_prod,
        'codigo_produto_omie', v_omie_prod,
        'descricao', v_title,
        'quantidade', v_qty,
        'valor_unitario', (v_item->>'unit_price')::numeric));
  end loop;

  update public.charges
     set status='pago', paid_at=now(), sale_id=v_sale, external_ref=p_external
   where id = v_ch.id;

  -- monta o que a Omie precisa
  select omie_client_id, cnpj into v_omie_cli, v_cnpj from public.units where id = v_ch.unit_id;
  select value into v_natureza  from public.settings where key='omie_natureza';
  select value into v_categoria from public.settings where key='omie_categoria';
  select value into v_conta     from public.settings where key='omie_conta';
  select value into v_etapa     from public.settings where key='omie_etapa';
  select coalesce(value,'true')='true' into v_sim from public.settings where key='modo_simulacao';

  insert into public.omie_queue (sale_id, charge_id, unit_id, unit_name, kind, payload, status)
  values (v_sale, v_ch.id, v_ch.unit_id, v_ch.unit_name, 'pedido_venda',
    jsonb_build_object(
      'codigo_pedido_integracao', v_sale,
      'codigo_cliente_omie',      v_omie_cli,
      'cnpj_filial',              v_cnpj,
      'filial',                   v_ch.unit_name,
      'data_previsao',            to_char(now(), 'DD/MM/YYYY'),
      'etapa',                    v_etapa,
      'codigo_natureza',          v_natureza,
      'codigo_categoria',         v_categoria,
      'codigo_conta_corrente',    v_conta,
      'forma_pagamento',          v_ch.method,
      'parcelas',                 v_ch.installments,
      'valor_total',              v_ch.amount,
      'itens',                    v_det),
    'pendente');

  perform public.log_action('cobranca_paga','charges',v_ch.id,
    jsonb_build_object('codigo',v_ch.code,'valor',v_ch.amount,'venda',v_sale,'simulada',v_sim));
  perform public.fn_notify(null, v_ch.unit_id, null, 'Pagamento confirmado',
    'A cobrança ' || v_ch.code || ' foi paga e a venda foi registrada.', 'pagamento', null);

  return v_sale;
end $$;

-- ---------------------------------------------------------------------
-- 10. Cancelar a cobrança
-- ---------------------------------------------------------------------
create or replace function public.fn_cancel_charge(p_code text, p_reason text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_unit uuid;
begin
  select id, unit_id into v_id, v_unit
    from public.charges where code = trim(p_code) and status = 'aguardando';
  if v_id is null then raise exception 'Nenhuma cobrança em aberto com este código.'; end if;
  if not (public.is_staff() or v_unit = public.my_unit()) then
    raise exception 'Sem permissão para cancelar esta cobrança.'; end if;

  update public.charges set status='cancelado', canceled_at=now(), note=coalesce(p_reason, note)
   where id = v_id;

  perform public.log_action('cobranca_cancelada','charges',v_id,
    jsonb_build_object('motivo',p_reason));
end $$;

-- ---------------------------------------------------------------------
-- 11. Cobranças em aberto de uma maquininha (a "fila da máquina")
-- ---------------------------------------------------------------------
create or replace function public.fn_charges_device(p_device text default null)
returns table (
  id uuid, code text, unit_name text, device_serial text, device_nickname text,
  amount numeric, method charge_method, installments integer,
  items jsonb, created_by_name text, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select c.id, c.code, c.unit_name, c.device_serial, c.device_nickname,
         c.amount, c.method, c.installments, c.items, c.created_by_name, c.created_at
    from public.charges c
   where c.status = 'aguardando'
     and (p_device is null or upper(trim(c.device_serial)) = upper(trim(p_device)))
     and (public.is_staff() or c.unit_id = public.my_unit())
   order by c.created_at;
$$;

-- ---------------------------------------------------------------------
-- 12. Marcar item da fila da Omie (usado pela função "api")
-- ---------------------------------------------------------------------
create or replace function public.fn_omie_marcar(
  p_id uuid, p_status queue_status, p_resposta jsonb default null, p_erro text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_sale uuid;
begin
  update public.omie_queue
     set status = p_status,
         response = coalesce(p_resposta, response),
         last_error = p_erro,
         attempts = attempts + 1,
         sent_at = case when p_status in ('enviado','simulado') then now() else sent_at end
   where id = p_id
  returning sale_id into v_sale;

  if v_sale is not null then
    update public.sales set omie_status = p_status where id = v_sale;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 13. Reenviar um item que deu erro
-- ---------------------------------------------------------------------
create or replace function public.fn_omie_reenviar(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Apenas o administrador pode reenviar.'; end if;
  update public.omie_queue set status='pendente', last_error=null where id = p_id;
end $$;

-- ---------------------------------------------------------------------
-- 14. Permissões
-- ---------------------------------------------------------------------
grant execute on function
  public.fn_create_charge(jsonb,charge_method,integer,text,text),
  public.fn_charge_by_code(text),
  public.fn_confirm_charge(text,text),
  public.fn_cancel_charge(text,text),
  public.fn_charges_device(text),
  public.fn_omie_reenviar(uuid)
to authenticated;

-- ---------------------------------------------------------------------

grant execute on function
  public.fn_create_charge(jsonb,charge_method,integer,text,text),
  public.fn_charge_by_code(text),
  public.fn_confirm_charge(text,text),
  public.fn_cancel_charge(text,text),
  public.fn_charges_device(text),
  public.fn_omie_reenviar(uuid)
to authenticated;


-- =====================================================================
--  FIM — versao 2.6
-- =====================================================================
