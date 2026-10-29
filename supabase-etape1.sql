-- ============================================================
--  Montoiz' Thaï Khmer Boxing — Espace adhérents — ÉTAPE 1
--  À coller dans Supabase : SQL Editor → New query → Run
--  Peut être relancé sans risque (ne supprime aucune donnée).
-- ============================================================

-- 1) L'équipe : bureau (gère tout) et coachs (consultent)
create table if not exists public.staff (
  email       text primary key,
  nom         text,
  role        text not null default 'bureau' check (role in ('bureau','coach')),
  created_at  timestamptz not null default now()
);

-- 2) Les adhérents (une ligne = un pratiquant, enfant ou adulte)
create table if not exists public.adherents (
  id               uuid primary key default gen_random_uuid(),
  saison           text not null default '2026-2027',
  nom              text not null,
  prenom           text not null,
  naissance        date,
  groupe           text,             -- ex : Enfants, Ados, Adultes, Compétition
  email            text,             -- email de connexion (adhérent majeur ou parent 1)
  email2           text,             -- 2e email autorisé (parent 2)
  telephone        text,
  licence_num      text,
  licence_ok       boolean not null default false,
  certificat_date  date,             -- on stocke la DATE, pas le document (données de santé)
  cotisation_due   numeric(8,2) not null default 0,
  cotisation_payee numeric(8,2) not null default 0,
  droit_image      boolean,          -- null = pas encore répondu
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists adherents_email_idx  on public.adherents (lower(email));
create index if not exists adherents_email2_idx on public.adherents (lower(email2));

-- Emails toujours enregistrés en minuscules
create or replace function public.tg_adherents_clean() returns trigger
language plpgsql as $$
begin
  new.email  := nullif(lower(trim(new.email)),  '');
  new.email2 := nullif(lower(trim(new.email2)), '');
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists adherents_clean on public.adherents;
create trigger adherents_clean before insert or update on public.adherents
for each row execute function public.tg_adherents_clean();

create or replace function public.tg_staff_clean() returns trigger
language plpgsql as $$
begin new.email := lower(trim(new.email)); return new; end $$;
drop trigger if exists staff_clean on public.staff;
create trigger staff_clean before insert or update on public.staff
for each row execute function public.tg_staff_clean();

-- 3) Fonctions utilitaires
create or replace function public.my_email() returns text
language sql stable as $$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function public.is_staff(r text default null) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff
                 where email = public.my_email() and (r is null or role = r))
$$;

-- Rôle de la personne connectée : 'bureau', 'coach' ou 'membre'
create or replace function public.mon_role() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select role from public.staff where email = public.my_email()), 'membre')
$$;

-- 4) Sécurité : chacun ne voit que ce qui le concerne
alter table public.staff     enable row level security;
alter table public.adherents enable row level security;

drop policy if exists adh_lire     on public.adherents;
drop policy if exists adh_ajouter  on public.adherents;
drop policy if exists adh_modifier on public.adherents;
drop policy if exists adh_suppr    on public.adherents;
create policy adh_lire on public.adherents for select to authenticated
  using ( public.is_staff() or email = public.my_email() or email2 = public.my_email() );
create policy adh_ajouter  on public.adherents for insert to authenticated with check ( public.is_staff('bureau') );
create policy adh_modifier on public.adherents for update to authenticated
  using ( public.is_staff('bureau') ) with check ( public.is_staff('bureau') );
create policy adh_suppr    on public.adherents for delete to authenticated using ( public.is_staff('bureau') );

drop policy if exists staff_lire  on public.staff;
drop policy if exists staff_gerer on public.staff;
create policy staff_lire  on public.staff for select to authenticated
  using ( public.is_staff() or email = public.my_email() );
create policy staff_gerer on public.staff for all to authenticated
  using ( public.is_staff('bureau') ) with check ( public.is_staff('bureau') );

-- Accès : rien pour les visiteurs non connectés, tout passe par les règles ci-dessus
revoke all on public.staff, public.adherents from anon;
grant select, insert, update, delete on public.staff, public.adherents to authenticated;
grant execute on function public.my_email(), public.is_staff(text), public.mon_role() to authenticated;

-- 5) Premier membre du bureau : l'email du club
insert into public.staff (email, nom, role)
values ('allexthaikhmerboxing@gmail.com', 'Bureau du club', 'bureau')
on conflict (email) do nothing;

-- Vérification : doit afficher la ligne du bureau
select * from public.staff;
