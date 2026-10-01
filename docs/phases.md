# Working phases

One Laravel API. The phone app and the admin website both use it. Finish a phase before starting the next one. Do not build app screens that need data the API does not have yet.

## Done

1. **App sides.** Tutor and Law advice on the welcome screen. Roles: student, tutor, lecturer, client, lawyer, legal counsel. Admin is not in the app.
2. **Website shell.** React and Tailwind in `web/`. Landing, admin sign-in, dashboard counts, approve a waiting profile.
3. **Learning tracks.** API tracks `a-l`, `o-l`, and `grade-5-scholarship`. A/L and O/L have subjects. Grade 5 scholarship is one programme. Admin page: `/learning`.
4. **App track picker.** A student chooses For A/L, For O/L, or For Grade 5 scholarship on the home screen. A/L and O/L show that track’s subjects. Grade 5 shows the programme, not a subject list. Law advice does not show these tracks.
6. **Law home.** A client picks a practice area, then a lawyer or legal counsel. The home says consultation, not Join class. The Advisers tab splits lawyers and legal counsel.

## Next

5. **Tutor and lecturer are different in the app.** Two directories. A lecturer has a class, not only a weekly one-to-one slot.
7. **People page on the website.** Filter by side and role. Approve and reject. Suspend a student or client.
8. **Packages, payments, lessons, questions on the website.** Learning packages belong to a track. Law packages belong to a practice area. Verify or reject a payment. Admin can close a question and does not answer it.
9. **Live session and a real payment slip.** Join opens a room. The slip is an uploaded file. Sinhala, Tamil, or English medium on a track. Sign-up and password reset in the app.

Phase 5 is app work. Phases 7 and 8 are website work. Phase 9 is both.
