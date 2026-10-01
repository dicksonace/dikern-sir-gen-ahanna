# සර් ගෙන් අහන්න — Mobile app

The phone app has two sides. People pick a side on the welcome screen, then sign in as a role on that side. Administrators do not sign in here. They use the website described in [website.md](website.md).

Both sides share one Laravel API (`backend/`) and one Flutter app (`mobile/`). The prototype reuses the same screens for both sides and only changes a few labels. That is why a lot of the real product is still missing.

## Sides and roles

| Side | Who asks | Who answers one to one | Who teaches a structured session |
|---|---|---|---|
| Tutor (learning) | Student | Tutor | Lecturer |
| Law advice | Client | Lawyer | Legal counsel |

Demo password for every account is `password`.

| Side | Role | Email | Opens |
|---|---|---|---|
| Tutor | Student | `student@sirgen.lk` | Learner home |
| Tutor | Tutor | `nimal@sirgen.lk` | Provider home |
| Tutor | Lecturer | `lecturer@sirgen.lk` | Provider home |
| Law advice | Client | `client@sirgen.lk` | Learner home |
| Law advice | Lawyer | `lawyer@sirgen.lk` | Provider home |
| Law advice | Legal counsel | `counsel@sirgen.lk` | Provider home |

`admin@sirgen.lk` is rejected by `POST /api/login`. The app must keep that account off the welcome screen.

## Tutor side — learning tracks

Learning is not a flat list of subjects. A student first chooses the exam they are sitting, then a subject inside that exam, then a tutor or a lecturer.

There are three tracks:

1. **For A/L** — G.C.E. Advanced Level.
2. **For O/L** — G.C.E. Ordinary Level.
3. **For Grade 5 scholarship** — the Grade 5 Scholarship exam.

### How the three tracks differ

**A/L and O/L** work the same way. The track contains many subjects. A student studies one or more subjects. A tutor or lecturer is approved for specific subjects inside a track, not for “maths” in general. An A/L Combined Mathematics tutor is not automatically an O/L Mathematics tutor.

Starter subjects, to be confirmed and edited from the website later:

- A/L: Combined Mathematics, Physics, Chemistry, Biology, Accounting, Economics, Business Studies, ICT, Sinhala, English.
- O/L: Mathematics, Science, English, Sinhala, History, ICT, Business & Accounting Studies.

**Grade 5 scholarship** is one programme, not a shelf of school subjects. The student is preparing for a single exam. Tutors and lecturers on this track teach that paper (language, mathematics, and the scholarship-style questions). The app should not ask a Grade 5 student to pick Chemistry.

### What a student should be able to do

The home (the “Ayubowan” screen) shows the track chips, upcoming lessons, open questions, and a subject count, then a live-class card. A/L and O/L list that track’s subjects. Grade 5 scholarship shows the programme text.

Still to build on this flow:

1. A student may follow more than one track. The home shows the one they selected.
2. Inside A/L or O/L, open one subject. Grade 5 scholarship stays the programme.
3. Find a **tutor** for weekly one-to-one help and instant questions, or a **lecturer** for a scheduled class.
4. Buy a package for that track and subject.
5. Join the live session, ask a question on that subject, and give a satisfaction point after a session.

Tabs that exist today: Home, Tutors, Ask, Package. They stay, but every list is filtered by the student’s track (and subject, except Grade 5).

### Tutor and lecturer

Both open the provider home (Home, Inbox, Earn, Profile). They are not the same job.

| | Tutor | Lecturer |
|---|---|---|
| Session | Weekly live help for one student, about two hours | A class on a track and subject, often more than one student |
| Questions | Instant replies on homework for their own students | Questions from students enrolled in their class |
| Listing | Shown under Tutors for the subjects they teach | Shown as a lecturer for those subjects, not mixed in as “just another tutor” |
| Pay | Commission on the student’s package | Commission on class enrolment |

The prototype stores both as a `tutor_profiles` row and sends both to the same shell. Separate class enrolment, a lecturer directory, and a real classroom are not built.

## Law advice side

Law is the second side of the same app. It is not a third learning track. A client is not studying for A/L.

Roles:

- **Client** — the person who needs advice. Same place in the app as a student.
- **Lawyer** — private, one-to-one advice. Same place as a tutor.
- **Legal counsel** — structured guidance and written opinions. Same place as a lecturer.

Practice areas already seeded: Family law, Property, Employment, Business. These are the law equivalent of subjects. They are not A/L, O/L, or Grade 5.

A client should:

1. Choose a practice area.
2. Read a lawyer or counsel profile (qualifications, years, languages, what they will and will not advise on).
3. Book a consultation package.
4. Ask a question and receive a reply.
5. See a clear line that this is general guidance, not a court filing, unless a later phase says otherwise.

The client home uses practice areas, consultations, and a lawyer or legal counsel. It does not say “Join class” or “Subjects”.

## What the prototype already does

Welcome screen: choose Tutor or Law advice, then a demo role. Manual email login remains. No admin button.

Learner shell (`mobile/lib/screens/student/student_shell.dart`):

- Learning home: upcoming lessons, open questions, subject count, and a Join class card, after the student picks A/L, O/L, or Grade 5 scholarship.
- Law home: practice-area chips, upcoming consultation, advisers split into lawyers and legal counsel, and an advice question on that area.
- Directory of approved providers.
- Ask a question with a subject and a provider.
- Packages and a bank-transfer payment screen with a slip flag. The slip is not a real upload.

Provider shell (`mobile/lib/screens/tutor/tutor_shell.dart`):

- Upcoming sessions, inbox of questions, earnings from commissions, profile and satisfaction points.

API (`backend/routes/api.php`), Sanctum token:

- `POST /api/register`, `POST /api/login`, `GET /api/me`, `POST /api/logout`
- `GET /api/subjects`, `/packages`, `/tutors`, `/tutors/{id}` — optional `division=tutor|law`
- Authenticated: subscriptions, lessons, questions, replies, satisfaction points, tutor earnings
- `POST /api/login` refuses `role=admin`

Data that exists: users (`role`, `division`), subjects, packages, tutor profiles, subscriptions, payments, lessons, questions, replies, satisfaction points, commissions.

## What is missing on the app

These are not small polish items. The prototype proves login and a shared lesson/question loop. The product below is not in the code yet.

### Tutor side

- The student home now picks A/L, O/L, or Grade 5 scholarship. A/L and O/L list that track’s subjects. Grade 5 shows the programme text.
- A student still cannot follow two tracks at once. The home shows one selected track.
- Tutors and lecturers are one directory. The student cannot tell a class lecturer from a weekly tutor.
- Join class does not open a real room. `meeting_room` is a string. There is no video, screen share, or attendance timer beyond `tracked_minutes`.
- A lecturer has no class roster and no “students in this A/L Physics class”.
- Packages are not tied to a track. A Grade 5 package and an A/L package are not different products in the database (`packages.division` is only `tutor` or `law`).
- The Ask form follows the selected track. Saved questions are still the student’s full list, and a question is not stored against a track.
- Payment is a prototype: bank text on screen, a checkbox that a slip was attached, admin verifies later. No file storage, no receipt, no failed-payment state in the UI.
- No parent account for Grade 5. The student account is the only learner login.
- No medium of study (Sinhala / Tamil / English), which A/L, O/L, and Grade 5 all need.
- No past papers, notes, or recordings.

### Law side

- The client home picks a practice area (Family law, Property, Employment, Business), then a lawyer or legal counsel. It does not show Join class, A/L, O/L, or Grade 5.
- Lawyer and counsel share one provider shell. A counsel does not yet have a separate written-opinion workspace.
- No engagement letter, no “this is not representation in court” notice, no conflict check.
- No document upload on a question (the API has `attachment_path`; the app does not send a file).
- Consultations are stored as `lessons`, so the data model still says “student” and “tutor”.

### Both sides

- Registration in the API accepts the six roles, but the app has no sign-up screen. Demo buttons and manual login only.
- No password reset in the app.
- No profile photo, language, or notification settings.
- One shell cannot show a person who is a tutor and also a lawyer. An account has one `division`.
- Copy is mostly English, with a Sinhala wordmark and “Ayubowan”. The product needs Sinhala for students and clients.
- The provider earnings screen is a list. It does not explain the commission rate or the month.

## Rules that stay true while we build

- A learning track belongs only to the tutor side. Law practice areas never appear inside A/L, O/L, or Grade 5.
- Grade 5 scholarship is one programme. Do not model it as a bag of A/L subjects.
- A tutor, lecturer, lawyer, or counsel is invisible in the app until an admin approves their profile.
- Admin never appears on the welcome screen and never receives a mobile token.
- The phone app keeps calling the same Laravel API. New screens should add API fields, not a second backend.
