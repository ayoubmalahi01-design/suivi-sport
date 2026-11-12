# Sport Performance 3.0

A multilingual, responsive PWA for institutional physical-education and sports-performance management. It uses Supabase for authentication, tenant-isolated data, database-enforced role approvals, private coach notebooks, attendance, test results, immutable scoring-scale versions, academic-year archiving, and private file storage.

## Quick start

1. Create a **new, clean Supabase project**. Do not run the clean-install migrations over an existing database without a separately reviewed migration plan.
2. Run `supabase/INSTALL_ALL.sql` once (or run the three ordered migration files instead; never do both).
3. Create the first auth user with no institution slug while the database has no institutions.
4. Edit and run `supabase/BOOTSTRAP_AR.sql` to create the first institution, owner profile, school year, and four core tests.
5. Build and test with `npm install`, `npm run check`, `npm test`, `npm run build`.
6. Upload the contents of `cloudflare-upload/` to a new Cloudflare Pages Direct Upload project.
7. Configure the app with the Supabase Project URL and Publishable/anon key only. Never expose `service_role` in the browser.

See [README_AR.md](README_AR.md) for the full Arabic setup and operating guide.

## Verification boundaries

Local syntax checks, domain tests, SQL structural checks, and static build are included. Live Supabase, email, Storage, multi-user RLS, and Cloudflare deployment must be verified in the owner's accounts after setup.

The app includes CSV paste workflows and true `.xlsx` exports (loaded on demand from the pinned SheetJS ESM package). See `docs/USER_GUIDE_AR.md` for paste column order and year archive behavior.
