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

The app **calls live Laravel APIs** (login, tutors, packages, lessons, questions, admin).

Tap a demo role on the welcome screen (password is always `password`).

### Demo accounts (password: `password`)
| Role | Email |
|------|--------|
| Admin | `admin@sirgen.lk` |
| Student | `student@sirgen.lk` |
| Tutor | `nimal@sirgen.lk` |

### `.env` DB settings (XAMPP default)
```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=sir_gen_ahanna
DB_USERNAME=root
DB_PASSWORD=
```
