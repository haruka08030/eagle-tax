-- This script will find all users in `auth.users` that do not have a
-- corresponding entry in `public.profiles` and create one for them.

insert into public.profiles (id)
select u.id
from auth.users u
left join public.profiles p on u.id = p.id
where p.id is null
on conflict (id) do nothing;
