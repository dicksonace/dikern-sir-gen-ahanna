@extends('admin.layout')

@section('title', 'Dashboard')

@section('content')
    <h1>Both sides of the app</h1>
    <p>People use the mobile app. You manage them here.</p>

    <div class="grid">
        <section class="card">
            <h2>Tutor</h2>
            <p>Students learn with tutors and lecturers.</p>
            <div class="stats">
                <div class="stat"><b>{{ $counts['tutor']['student'] }}</b><span>Students</span></div>
                <div class="stat"><b>{{ $counts['tutor']['tutor'] }}</b><span>Tutors</span></div>
                <div class="stat"><b>{{ $counts['tutor']['lecturer'] }}</b><span>Lecturers</span></div>
            </div>
        </section>
        <section class="card">
            <h2>Law advice</h2>
            <p>Clients ask lawyers and legal counsel.</p>
            <div class="stats">
                <div class="stat"><b>{{ $counts['law']['client'] }}</b><span>Clients</span></div>
                <div class="stat"><b>{{ $counts['law']['lawyer'] }}</b><span>Lawyers</span></div>
                <div class="stat"><b>{{ $counts['law']['counsel'] }}</b><span>Legal counsel</span></div>
            </div>
        </section>
    </div>

    <section class="card" style="margin-top: 16px;">
        <h2>Waiting for approval</h2>
        @if ($pending->isEmpty())
            <p>No pending tutor, lecturer, lawyer, or counsel profiles.</p>
        @else
            <table>
                <thead>
                    <tr><th>Name</th><th>Side</th><th>Role</th><th></th></tr>
                </thead>
                <tbody>
                    @foreach ($pending as $profile)
                        <tr>
                            <td>{{ $profile->user?->name }}</td>
                            <td>{{ $profile->user?->division === 'law' ? 'Law advice' : 'Tutor' }}</td>
                            <td><span class="pill">{{ str_replace('_', ' ', $profile->user?->role ?? '') }}</span></td>
                            <td>
                                <form method="POST" action="{{ route('admin.approve', $profile) }}">
                                    @csrf
                                    <button type="submit">Approve</button>
                                </form>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        @endif
    </section>

    <section class="card" style="margin-top: 16px;">
        <h2>People</h2>
        <table>
            <thead>
                <tr><th>Name</th><th>Email</th><th>Side</th><th>Role</th></tr>
            </thead>
            <tbody>
                @foreach ($users as $person)
                    <tr>
                        <td>{{ $person->name }}</td>
                        <td>{{ $person->email }}</td>
                        <td>{{ $person->division === 'law' ? 'Law advice' : 'Tutor' }}</td>
                        <td><span class="pill">{{ $person->role }}</span></td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </section>
@endsection
