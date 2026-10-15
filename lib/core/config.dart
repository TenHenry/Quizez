/// Deep link that brings the user back to the app after Google sign-in or a password reset e-mail.
/// It must be added to Supabase: Authentication -> URL Configuration -> Redirect URLs.
const authRedirectUrl = 'io.supabase.quizez://login-callback/';
