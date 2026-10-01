# සර් ගෙන් අහන්න — Prototype

Student learning & tutor support platform (investor prototype).

| Layer | Stack | Folder |
|-------|--------|--------|
| Mobile | Flutter | `mobile/` |
| API | Laravel 12 + Sanctum | `backend/` |
| Database | MySQL (XAMPP) | `sir_gen_ahanna` |

## Quick start

### 1) MySQL (XAMPP)
1. Start **Apache + MySQL** in XAMPP
2. Create database `sir_gen_ahanna` (phpMyAdmin or CLI)

### 2) Backend
```bash
cd backend
composer install
php artisan migrate:fresh --seed
php artisan serve --host=0.0.0.0 --port=8000
```

API: `http://127.0.0.1:8000/api`  
Android emulator uses `http://10.0.2.2:8000/api` automatically.

### 3) Flutter
```bash
cd mobile
flutter pub get
flutter run
```

The app **calls live Laravel APIs** (login, tutors, packages, lessons, questions).

Product notes:

- [docs/app.md](docs/app.md) — both sides of the phone app. Learning is three tracks: A/L, O/L, and Grade 5 scholarship.
- [docs/phases.md](docs/phases.md) — the order of work. Phase 5 is next: separate tutor and lecturer in the app.

Tap a demo role on the welcome screen (password is always `password`).

### Demo accounts (password: `password`)

The mobile app has two sides. Admin is not on that screen.

| Side | Role | Email |
|------|------|--------|
| Tutor | Student | `student@sirgen.lk` |
| Tutor | Tutor | `nimal@sirgen.lk` |
| Tutor | Lecturer | `lecturer@sirgen.lk` |
| Law advice | Client | `client@sirgen.lk` |
| Law advice | Lawyer | `lawyer@sirgen.lk` |
| Law advice | Legal counsel | `counsel@sirgen.lk` |

Admin signs in on the React website, not the app.

```bash
cd web
npm install
npm run dev
```

Open [http://127.0.0.1:5173](http://127.0.0.1:5173) while the API is running on port 8000.  
Email `admin@sirgen.lk`, password `password`.

### `.env` DB settings (XAMPP default)
```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=sir_gen_ahanna
DB_USERNAME=root
DB_PASSWORD=
```
