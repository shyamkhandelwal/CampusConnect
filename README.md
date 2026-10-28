# CampusConnect

CampusConnect is a welcoming lost-and-found board for college communities. It gives students a place to report missing belongings, post items they find, and safely reunite owners with their things through a private claim workflow.

## What it includes

- A searchable discover page with lost/found, category, approximate location, date, and sort filters
- Dedicated item details and privacy-conscious report forms with image preview and validation
- Private claims, poster review actions, status updates, reunite flow, and listing reports
- Personal activity dashboard for listings and incoming/outgoing claims
- Local demo mode that runs without an account or Supabase project
- Supabase Auth, PostgreSQL, Row Level Security, and private image storage adapter for connected mode
- Responsive mobile layouts and keyboard-accessible controls

## Run the demo on macOS

Install Node.js 20.19+ or 22.12+, then from this folder:

```sh
npm install
npm run dev
```

Open the local URL printed by Vite (usually `http://localhost:5173`). With no Supabase keys configured, CampusConnect starts in demo mode. Listings, claims, reports, and demo changes are stored in this browser's `localStorage`; they are not shared with other people or devices. The dashboard has a **Reset demo** action to restore the original sample set.

## Connected mode with Supabase

1. Create a Supabase project and copy `.env.example` to `.env.local`.
2. Add the project's **Project URL** to `VITE_SUPABASE_URL` and its public **anon/publishable key** to `VITE_SUPABASE_ANON_KEY`.
3. In the Supabase SQL editor, run [`supabase/schema.sql`](supabase/schema.sql).
4. In Authentication settings, configure the allowed local redirect URL (for example `http://localhost:5173/**`) and email confirmation to match your preferred sign-in flow.
5. Restart the Vite server. The header changes to **Connected**, and account actions use Supabase Auth.

The browser client must only use the public anon/publishable key. Never put a Supabase `service_role` key into a `VITE_` variable or frontend file. The item photo bucket is private and uses signed URLs. SQL policies scope listing mutations to their owners, claims to the claimant and listing owner, reports to their submitter, and image writes/deletes to the owner's storage folder.

The connected adapter and SQL are provided as setup code; they have **not** been verified against a live Supabase project in this environment. Apply the schema in a disposable project and review its policies before handling real claims. Supabase project configuration, Auth email delivery, and production moderation are not included.

## Project structure

- `src/App.tsx` — routes, pages, forms, dialogs, and UI workflows
- `src/data/demo.ts` — example listings
- `src/lib/data.ts` — local persistence and Supabase data adapter
- `src/lib/supabase.ts` — optional Supabase browser client
- `src/types.ts` — shared item, claim, and report types
- `src/styles.css` — responsive visual system and component styles
- `supabase/schema.sql` — database, RLS, indexes, and storage setup

## Screenshots

Add desktop and mobile screenshots here after capturing the running app.

## Privacy and safety

Public listing details use approximate locations and do not ask for phone numbers or email addresses. Claim details are treated as private content and are protected by database policies in connected mode. Demo content and demo claims are local to the current browser profile. Meet in a busy public campus place and do not share PINs, passwords, or identity-document numbers.

## Limitations and next steps

- Demo data lives in one browser and is not a shared service.
- Connected mode requires a configured Supabase project and the supplied SQL policies.
- Moderation reports are stored securely, but a moderator review console is not included.
- Email confirmation and password recovery depend on Supabase Auth settings.
- Custom categories, notifications, and verified campus identities are future improvements.
