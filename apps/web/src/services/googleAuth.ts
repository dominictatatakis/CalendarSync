import { Platform } from 'react-native';

// Google OAuth configuration
const GOOGLE_WEB_CLIENT_ID = '995263830606-1o5ivn1as03p31lssfhlf2ue3b1cs8r7.apps.googleusercontent.com';
const CALENDAR_SCOPE = 'https://www.googleapis.com/auth/calendar.readonly';

function getRedirectUri(): string {
  if (Platform.OS !== 'web') return 'calendarsync://auth';
  // Must exactly match what's registered in Google Cloud Console
  return window.location.origin;
}

/**
 * Opens a Google OAuth popup to get a Calendar access token.
 * Uses the implicit (token) flow: Google returns the access token directly in
 * the redirect fragment. Browser apps can't hold a client secret, and Google's
 * token endpoint requires one for Web clients even with PKCE, so the
 * authorization-code flow is not usable here.
 */
export async function connectGoogleCalendar(): Promise<string> {
  if (Platform.OS !== 'web') {
    throw new Error('Use expo-auth-session for native');
  }

  const state = Math.random().toString(36).substring(2);
  const redirectUri = getRedirectUri();

  const params = new URLSearchParams({
    client_id: GOOGLE_WEB_CLIENT_ID,
    redirect_uri: redirectUri,
    response_type: 'token',
    scope: `openid email profile ${CALENDAR_SCOPE}`,
    state,
    prompt: 'consent',
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

          // Implicit flow returns the token in the URL fragment:
          //   #access_token=...&state=...&expires_in=...
          const urlObj = new URL(url);
          const fragment = new URLSearchParams(urlObj.hash.replace(/^#/, ''));
          const accessToken = fragment.get('access_token');
          const returnedState = fragment.get('state');
          const error = fragment.get('error') ?? urlObj.searchParams.get('error');

          if (error) {
            reject(new Error(`Google auth error: ${error}`));
            return;
          }
          if (returnedState !== state) {
            reject(new Error('State mismatch'));
            return;
          }
          if (!accessToken) {
            reject(new Error('No access token returned'));
            return;
          }
          resolve(accessToken);
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
