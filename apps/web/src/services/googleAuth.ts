import { Platform } from 'react-native';

// Google OAuth configuration
const GOOGLE_WEB_CLIENT_ID = '995263830606-vj1t6lf3alm90v3eh7dsu3j9eavsslup.apps.googleusercontent.com';
const CALENDAR_SCOPE = 'https://www.googleapis.com/auth/calendar.readonly';

function getRedirectUri(): string {
  if (Platform.OS !== 'web') return 'calendarsync://auth';
  // Must exactly match what's registered in Google Cloud Console
  return window.location.origin;
}

/**
 * Generate a random code verifier for PKCE
 */
function generateCodeVerifier(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, b => b.toString(36).padStart(2, '0')).join('').slice(0, 64);
}

/**
 * Generate the code challenge from the verifier (S256)
 */
async function generateCodeChallenge(verifier: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * Opens a Google OAuth popup to get a Calendar access token.
 * Uses authorization code flow with PKCE (recommended for SPAs).
 */
export async function connectGoogleCalendar(): Promise<string> {
  if (Platform.OS !== 'web') {
    throw new Error('Use expo-auth-session for native');
  }

  const codeVerifier = generateCodeVerifier();
  const codeChallenge = await generateCodeChallenge(codeVerifier);
  const state = Math.random().toString(36).substring(2);
  const redirectUri = getRedirectUri();

  const params = new URLSearchParams({
    client_id: GOOGLE_WEB_CLIENT_ID,
    redirect_uri: redirectUri,
    response_type: 'code',
    scope: `openid email profile ${CALENDAR_SCOPE}`,
    state,
    prompt: 'consent',
    access_type: 'offline',
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  });

  const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?${params}`;
  const width = 500;
  const height = 600;
  const left = window.screenX + (window.innerWidth - width) / 2;
  const top = window.screenY + (window.innerHeight - height) / 2;

  return new Promise((resolve, reject) => {
    const popup = window.open(
      authUrl,
      'google-calendar-auth',
      `width=${width},height=${height},left=${left},top=${top}`,
    );

    if (!popup) {
      reject(new Error('Popup blocked. Please allow popups for this site.'));
      return;
    }

    const interval = setInterval(async () => {
      try {
        if (popup.closed) {
          clearInterval(interval);
          reject(new Error('Auth cancelled'));
          return;
        }
        const url = popup.location.href;
        if (url.startsWith(redirectUri)) {
          clearInterval(interval);
          popup.close();

          const urlObj = new URL(url);
          const code = urlObj.searchParams.get('code');
          const returnedState = urlObj.searchParams.get('state');
          const error = urlObj.searchParams.get('error');

          if (error) {
            reject(new Error(`Google auth error: ${error}`));
            return;
          }
          if (returnedState !== state) {
            reject(new Error('State mismatch'));
            return;
          }
          if (!code) {
            reject(new Error('No authorization code returned'));
            return;
          }

          // Exchange code for tokens using PKCE (no client secret needed)
          try {
            const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
              method: 'POST',
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
              body: new URLSearchParams({
                client_id: GOOGLE_WEB_CLIENT_ID,
                code,
                code_verifier: codeVerifier,
                grant_type: 'authorization_code',
                redirect_uri: redirectUri,
              }),
            });
            const tokenJson = await tokenRes.json();
            if (tokenJson.error) {
              reject(new Error(tokenJson.error_description || tokenJson.error));
              return;
            }
            resolve(tokenJson.access_token);
          } catch (err: any) {
            reject(new Error(`Token exchange failed: ${err.message}`));
          }
        }
      } catch {
        // Cross-origin — popup hasn't redirected back yet
      }
    }, 200);

    // Timeout after 5 minutes
    setTimeout(() => {
      clearInterval(interval);
      if (!popup.closed) popup.close();
      reject(new Error('Auth timed out'));
    }, 300000);
  });
}

/**
 * Fetches all calendars the user has access to.
 */
export async function fetchGoogleCalendarList(accessToken: string): Promise<GoogleCalendarInfo[]> {
  const res = await fetch(
    'https://www.googleapis.com/calendar/v3/users/me/calendarList?minAccessRole=reader',
    { headers: { Authorization: `Bearer ${accessToken}` } }
  );
  const json = await res.json();
  if (!json.items) return [];
  return (json.items as any[]).map(cal => ({
    id: cal.id,
    name: cal.summary,
    color: cal.backgroundColor ?? '#4285F4',
    primary: cal.primary ?? false,
    selected: cal.selected ?? true,
  }));
}

export interface GoogleCalendarInfo {
  id: string;
  name: string;
  color: string;
  primary: boolean;
  selected: boolean;
}
