<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin login — සර් ගෙන් අහන්න</title>
    <style>
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #095456; font-family: "Segoe UI", sans-serif; color: #1a2b2c; }
        form { width: min(420px, calc(100% - 32px)); background: white; border-radius: 18px; padding: 28px; }
        h1 { margin: 0 0 6px; font-size: 24px; }
        p { margin: 0 0 18px; color: #5c6b73; }
        label { display: block; font-size: 13px; font-weight: 700; margin-bottom: 6px; }
        input { width: 100%; box-sizing: border-box; border: 1px solid #e3e8ea; border-radius: 10px; padding: 12px; margin-bottom: 14px; font-size: 15px; }
        button { width: 100%; border: 0; border-radius: 10px; background: #0d7377; color: white; padding: 12px; font-weight: 700; font-size: 15px; }
        .error { color: #9b2335; font-size: 13px; margin: -8px 0 12px; }
    </style>
</head>
<body>
    <form method="POST" action="{{ route('admin.login.submit') }}">
        @csrf
        <h1>Admin sign in</h1>
        <p>This website manages the Tutor side and the Law advice side. It is not inside the mobile app.</p>
        <label for="email">Email</label>
        <input id="email" name="email" type="email" value="{{ old('email', 'admin@sirgen.lk') }}" required autofocus>
        @error('email')<div class="error">{{ $message }}</div>@enderror
        <label for="password">Password</label>
        <input id="password" name="password" type="password" required>
        <button type="submit">Sign in</button>
    </form>
</body>
</html>
