# සර් ගෙන් අහන්න — Website

The website is where an administrator runs both sides of the app. It is not a second copy of the phone UI, and it is not a place for students, tutors, clients, or lawyers to do their daily work.

It will be a **React + Tailwind** app. It will use the **same Laravel backend** that the Flutter app already uses (`backend/`, Sanctum, MySQL). Do not create a second API or a second database.

The Blade pages at `/admin/login` are a temporary stand-in so admin login exists today. They are replaced by this website. Do not keep adding features to those Blade views.

## Stack

| Piece | Choice |
|---|---|
| UI | React |
| Style | Tailwind CSS |
| Build | Vite |
| Folder | `web/` at the repo root, next to `mobile/` and `backend/` |
| API | Existing Laravel routes under `/api` |
| Auth | Laravel Sanctum. Email and password. Only `role=admin` may enter. |
| Data | Same MySQL database as the app |

The React app sends `Authorization: Bearer <token>`. `POST /api/login` currently rejects admin accounts so the phone cannot sign them in. The website needs a dedicated admin login response (see Phase 1) that still refuses every non-admin role.

Local development:

- API: `php artisan serve` on port 8000
- Website: Vite dev server, proxy `/api` to that Laravel app
- CORS must allow the Vite origin

Production can host the built React files on the same domain as Laravel, or on a subdomain, as long as both talk to this API.

## Who signs in

One role: **administrator**.

Demo: `admin@sirgen.lk` / `password`.

If a student, tutor, lecturer, client, lawyer, or counsel tries this login, the website shows an error and does not create a session. Their work stays in the Flutter app.

## What the website manages

Two areas in the navigation, matching the app:

1. **Learning** — the tutor side.
2. **Law advice** — the law side.

Plus shared tools: people, approvals, payments, packages, and a simple overview.

### Learning

The learning area is built around the three tracks from [app.md](app.md):

- For A/L
- For O/L
- For Grade 5 scholarship

An admin can:

- Turn a track on or off.
- Add and edit subjects under A/L and under O/L.
- Edit the Grade 5 scholarship programme as one programme (name, medium, description), not as a list of unrelated subjects.
- Set the medium: Sinhala, Tamil, or English.
- Approve or reject a tutor or lecturer, and set which tracks and subjects they may teach.
- See students and which track they are on.
- Create packages per track (price, weekly hours, whether instant questions are included).
- See lessons, open questions, and subscriptions for that track.
- Verify a payment slip and see the commission that will be owed to the tutor or lecturer.

### Law advice

An admin can:

- Edit practice areas (Family law, Property, Employment, Business, and later ones).
- Approve or reject a lawyer or legal counsel, and set their practice areas.
- See clients and their open questions.
- Create consultation packages.
- Verify payments for law packages.
- Read a question thread when a dispute or a refund needs a decision.

Law screens must not offer A/L, O/L, or Grade 5 scholarship. Those tracks do not exist on this side.

## Phases

Each phase ends with something an admin can click. Do not start a later phase by skipping the API the screens need. The phone app keeps working through every phase.

### Phase 1 — Website shell and admin login

Build `web/` with Vite, React, and Tailwind. One layout: sidebar, top bar, and a main panel. Tailwind only, no second CSS framework.

Screens:

- Login.
- Overview with two cards: Learning, and Law advice. Each card shows counts of its roles (the Blade dashboard already calculates these).
- Log out.

API work on the existing backend:

- `POST /api/admin/login` — same credentials check as `POST /api/login`, but it **allows** `role=admin` and **rejects** everyone else. Returns a Sanctum token and the admin user.
- `GET /api/admin/overview` — counts per role and per side, plus pending approvals and pending payments.
- Keep `POST /api/login` rejecting admin, so the phone app does not change.

Done when an admin can sign in from the React app, see both sides, and refresh the page without losing the token (store it the same way the Flutter app stores its token, in local storage for this first phase).

### Phase 2 — Learning tracks

This is the gap the app docs call out. The database has `subjects` with no exam track. Add a `tracks` concept on the backend before the React forms pretend it exists.

API and data:

- Tracks: `a-l`, `o-l`, `grade-5-scholarship`. Fields: name, slug, kind (`subjects` or `programme`), active.
- Subjects belong to a track. Grade 5 uses kind `programme` and does not require a subject row for each topic.
- `GET /api/admin/tracks` and write endpoints for tracks and subjects.
- Public `GET /api/subjects` gains an optional `track` filter so the phone can catch up later. Until the app is updated, existing tutor subjects still return.

Screens:

- Track list: A/L, O/L, Grade 5 scholarship.
- Subject editor for A/L and O/L.
- Grade 5 programme editor.
- Empty states and validation (duplicate slug, empty name).

Done when an admin can create “A/L Physics” and it is stored under the A/L track, and Grade 5 is edited as one programme.

### Phase 3 — People and approvals

Screens:

- People table with filters: side, role, track, status.
- Profile review for a tutor, lecturer, lawyer, or counsel: bio, qualifications, tracks or practice areas, approve, reject.
- Student and client rows are read-only except status (active / suspended).

API:

- `GET /api/admin/users`
- `GET /api/admin/profiles/pending`
- `POST /api/admin/profiles/{id}/approve` and `.../reject`
- The existing `/api/admin/pending-tutors` and `.../approve` can stay until these replace them. New React screens call the new routes.

Done when a pending lecturer does not appear in the app directory until Approve is clicked here.

### Phase 4 — Packages, payments, lessons, questions

Screens, split by the sidebar section so Learning and Law advice do not share one mixed table:

- Packages: create and archive. A learning package requires a track. A law package requires a practice area. Grade 5 packages attach to the programme, not to a fake subject.
- Payments: pending slips, amount, person, package, Verify or Reject.
- Lessons / consultations: list, status, who is booked.
- Questions: list and open a thread. Admin can close a thread. Admin does not answer as the tutor or the lawyer.

API:

- Admin CRUD for packages.
- The current pending-payment and verify endpoints, extended with reject and a note.
- Admin list endpoints for lessons and questions, filtered by `division` and, for learning, by `track`.

Done when verifying a payment from the React app marks the subscription active through the same tables the phone already reads.

### Phase 5 — Commissions and the handoff

Screens:

- Monthly commission per tutor, lecturer, lawyer, and counsel.
- Mark a commission paid.

Then stop expanding the Blade admin. Remove the temporary Blade dashboard once the React overview, approvals, and payments cover the same actions. Leave Laravel as the API only.

Done when an admin can run a week of approvals and payments without opening `/admin` on the Laravel welcome host, and the phone app still loads lessons from the same database.

## Screens that are out of scope

- A public marketing site. This plan is the admin website.
- Student, tutor, client, or lawyer dashboards on the web. Those stay in Flutter.
- Building A/L content, past papers, or video hosting inside the website. The website only manages the records. The app plays the session.
- A second auth system (no Firebase, no separate Node API).

## Visual

Use the app colours so the two products feel related: teal `#0D7377`, deep teal `#095456`, sand background `#F7F4EF`, ink text `#1A2B2C`. Tailwind theme tokens, not one-off hex on every component.

Learning and Law advice should be obvious in the sidebar. A learning screen never shows a practice area picker. A law screen never shows A/L, O/L, or Grade 5 scholarship.

## Order of work

1. Phase 1, so the React app exists and only admins enter.
2. Phase 2, so A/L, O/L, and Grade 5 scholarship exist in the API before more app screens are built on the old flat subject list.
3. Phase 3, then Phase 4, then Phase 5.

The Flutter track picker (student chooses A/L, O/L, or Grade 5 scholarship) is app work documented in [app.md](app.md). It should follow Phase 2, because it needs the track API. It is not a page of this website.
