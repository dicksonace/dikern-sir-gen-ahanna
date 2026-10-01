<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Admin') — සර් ගෙන් අහන්න</title>
    <style>
        :root { color-scheme: light; --teal: #0d7377; --ink: #1a2b2c; --muted: #5c6b73; --sand: #f7f4ef; --line: #e3e8ea; }
        * { box-sizing: border-box; }
        body { margin: 0; font-family: "Segoe UI", sans-serif; background: var(--sand); color: var(--ink); }
        a { color: var(--teal); }
        header { display: flex; justify-content: space-between; align-items: center; gap: 16px; padding: 18px 28px; background: #095456; color: white; }
        header strong { font-size: 18px; }
        header span { display: block; color: rgba(255,255,255,.75); font-size: 13px; font-weight: 400; }
        header form { margin: 0; }
        button, .button { border: 0; border-radius: 10px; background: white; color: #095456; padding: 8px 14px; font-weight: 700; cursor: pointer; }
        main { max-width: 1100px; margin: 0 auto; padding: 28px; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
        .card { background: white; border: 1px solid var(--line); border-radius: 16px; padding: 18px; }
        h1, h2 { margin: 0 0 8px; }
        h2 { font-size: 18px; }
        p { color: var(--muted); }
        .stats { display: flex; gap: 10px; flex-wrap: wrap; margin-top: 12px; }
        .stat { background: var(--sand); border-radius: 12px; padding: 10px 12px; min-width: 110px; }
        .stat b { display: block; font-size: 22px; }
        .stat span { color: var(--muted); font-size: 13px; }
        table { width: 100%; border-collapse: collapse; margin-top: 8px; }
        th, td { text-align: left; padding: 10px 8px; border-bottom: 1px solid var(--line); font-size: 14px; }
        th { color: var(--muted); font-weight: 600; }
        .pill { display: inline-block; border-radius: 999px; padding: 2px 8px; background: #e7f4f4; color: #095456; font-size: 12px; font-weight: 700; }
        .flash { background: #e7f6ea; color: #146c2e; border-radius: 12px; padding: 12px 14px; margin-bottom: 16px; }
        @media (max-width: 800px) { .grid { grid-template-columns: 1fr; } main, header { padding-left: 16px; padding-right: 16px; } }
    </style>
</head>
<body>
    <header>
        <div>
            <strong>සර් ගෙන් අහන්න</strong>
            <span>Admin website</span>
        </div>
        @auth
            <form method="POST" action="{{ route('admin.logout') }}">
                @csrf
                <button type="submit">Log out</button>
            </form>
        @endauth
    </header>
    <main>
        @if (session('status'))
            <div class="flash">{{ session('status') }}</div>
        @endif
        @yield('content')
    </main>
</body>
</html>
