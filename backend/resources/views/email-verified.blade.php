<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Email confirmed</title>
    <style>
        body { margin: 0; font-family: Georgia, serif; background: #F7F4EF; color: #1A2B2C; }
        main { max-width: 420px; margin: 12vh auto; background: white; border-radius: 24px; padding: 32px; }
        h1 { font-size: 28px; margin: 0 0 12px; }
        p { line-height: 1.5; color: #5C6B73; }
        .mark { width: 48px; height: 48px; border-radius: 16px; background: #0D7377; margin-bottom: 16px; }
    </style>
</head>
<body>
    <main>
        <div class="mark"></div>
        <h1>{{ $title ?? ($ok ? 'Email confirmed' : 'That code did not work') }}</h1>
        <p>{{ $message }}</p>
    </main>
</body>
</html>
