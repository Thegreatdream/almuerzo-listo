-- =========================================================
-- Almuerzo Listo · Base de datos (Supabase / PostgreSQL)
-- Pegue todo este archivo en Supabase → SQL Editor → Run
-- =========================================================

-- Restaurantes: cada dueño tiene el suyo, con su enlace (slug)
create table if not exists public.restaurants (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  slug        text not null unique
              check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug) between 3 and 40),
  nombre      text not null check (length(nombre) between 2 and 80),
  whatsapp    text,
  direccion   text,
  created_at  timestamptz not null default now()
);
alter table public.restaurants enable row level security;
drop policy if exists "Cualquiera ve restaurantes" on public.restaurants;
create policy "Cualquiera ve restaurantes" on public.restaurants
  for select using (true);
drop policy if exists "Dueño crea su restaurante" on public.restaurants;
create policy "Dueño crea su restaurante" on public.restaurants
  for insert with check (owner = auth.uid());
drop policy if exists "Dueño edita su restaurante" on public.restaurants;
create policy "Dueño edita su restaurante" on public.restaurants
  for update using (owner = auth.uid()) with check (owner = auth.uid());

-- Menús: uno por restaurante y por día
create table if not exists public.menus (
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  fecha         date not null,
  data          jsonb not null,
  updated_at    timestamptz not null default now(),
  primary key (restaurant_id, fecha)
);
alter table public.menus enable row level security;
drop policy if exists "Cualquiera ve menús" on public.menus;
create policy "Cualquiera ve menús" on public.menus for select using (true);
drop policy if exists "Dueño maneja sus menús" on public.menus;
create policy "Dueño maneja sus menús" on public.menus
  for all
  using (exists (select 1 from public.restaurants r where r.id = restaurant_id and r.owner = auth.uid()))
  with check (exists (select 1 from public.restaurants r where r.id = restaurant_id and r.owner = auth.uid()));

-- Pedidos: numerados por día (#1, #2, #3…) dentro de cada restaurante
create table if not exists public.orders (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  fecha         date not null default (now() at time zone 'America/Bogota')::date,
  numero        int  not null,
  token         uuid not null default gen_random_uuid() unique,
  cliente       text not null,
  telefono      text,
  hora          text,
  cantidad      int  not null check (cantidad between 1 and 50),
  eleccion      jsonb not null default '{}'::jsonb,
  extras        jsonb not null default '[]'::jsonb,
  total         int  not null,
  estado        text not null default 'nuevo'
                check (estado in ('nuevo','preparando','listo','entregado','cancelado')),
  created_at    timestamptz not null default now()
);
create index if not exists orders_rest_fecha on public.orders (restaurant_id, fecha, numero);
alter table public.orders enable row level security;
-- Solo el dueño ve y cambia los pedidos de su restaurante.
-- Los clientes NO escriben directo: usan la función crear_pedido (abajo).
drop policy if exists "Dueño ve sus pedidos" on public.orders;
create policy "Dueño ve sus pedidos" on public.orders
  for select using (exists (select 1 from public.restaurants r where r.id = restaurant_id and r.owner = auth.uid()));
drop policy if exists "Dueño actualiza sus pedidos" on public.orders;
create policy "Dueño actualiza sus pedidos" on public.orders
  for update using (exists (select 1 from public.restaurants r where r.id = restaurant_id and r.owner = auth.uid()));

-- Pedidos en vivo para el panel del restaurante
do $$ begin
  alter publication supabase_realtime add table public.orders;
exception when duplicate_object then null; end $$;

-- Crear un pedido: el total se calcula en el servidor con los precios del menú
-- (así nadie puede cambiar el precio desde el celular).
create or replace function public.crear_pedido(
  p_slug text, p_cliente text, p_telefono text, p_hora text,
  p_cantidad int, p_eleccion jsonb, p_extras jsonb
) returns table (o_numero int, o_token uuid, o_total int)
language plpgsql security definer set search_path = public as $$
declare
  r public.restaurants;
  m jsonb;
  hoy date := (now() at time zone 'America/Bogota')::date;
  precio int;
  extra_total int := 0;
  e text;
  n int;
  t uuid;
  tot int;
begin
  select * into r from public.restaurants where slug = p_slug;
  if not found then raise exception 'Restaurante no encontrado'; end if;
  select data into m from public.menus where restaurant_id = r.id and fecha = hoy;
  if m is null then raise exception 'Hoy todavía no hay menú publicado'; end if;
  if p_cantidad is null or p_cantidad < 1 or p_cantidad > 50 then raise exception 'Cantidad no válida'; end if;
  if coalesce(length(trim(p_cliente)), 0) < 2 then raise exception 'Escriba su nombre'; end if;

  precio := coalesce((m->>'precio')::int, 0);
  for e in select jsonb_array_elements_text(coalesce(p_extras, '[]'::jsonb)) loop
    extra_total := extra_total + coalesce((
      select (x->>'precio')::int from jsonb_array_elements(coalesce(m->'extras','[]'::jsonb)) x
      where x->>'nombre' = e limit 1), 0);
  end loop;
  tot := (precio + extra_total) * p_cantidad;

  -- Numeración sin repetidos aunque lleguen dos pedidos al mismo tiempo
  perform pg_advisory_xact_lock(hashtext(r.id::text || hoy::text));
  select coalesce(max(o.numero), 0) + 1 into n
    from public.orders o where o.restaurant_id = r.id and o.fecha = hoy;

  insert into public.orders (restaurant_id, fecha, numero, cliente, telefono, hora, cantidad, eleccion, extras, total)
  values (r.id, hoy, n, left(trim(p_cliente), 60), left(p_telefono, 20), left(p_hora, 40),
          p_cantidad, coalesce(p_eleccion, '{}'::jsonb), coalesce(p_extras, '[]'::jsonb), tot)
  returning orders.token into t;

  return query select n, t, tot;
end $$;

-- Consultar el estado de un pedido con su código (para el cliente)
create or replace function public.estado_pedido(p_token uuid)
returns table (o_numero int, o_estado text, o_restaurante text)
language sql security definer set search_path = public as $$
  select o.numero, o.estado, r.nombre
  from public.orders o join public.restaurants r on r.id = o.restaurant_id
  where o.token = p_token;
$$;

grant execute on function public.crear_pedido(text, text, text, text, int, jsonb, jsonb) to anon, authenticated;
grant execute on function public.estado_pedido(uuid) to anon, authenticated;
