import { Platform } from 'react-native';

// Microsoft identity platform OAuth configuration.
// The client ID comes from the Azure app registration ("CalendarSync Web").
// Redirect URIs must be registered as type "spa" so the token endpoint
// allows CORS for the PKCE code exchange (no client secret needed).
export const OUTLOOK_CLIENT_ID = 'OUTLOOK_CLIENT_ID_PLACEHOLDER';

const AUTHORITY = 'https://login.microsoftonline.com/common';
const GRAPH_SCOPE = 'openid profile email https://graph.microsoft.com/Calendars.Read';

export function isOutlookConfigured(): boolean {
  return !OUTLOOK_CLIENT_ID.includes('PLACEHOLDER');
}

function getRedirectUri(): string {
  if (Platform.OS !== 'web') return 'calendarsync://auth';
  // Must exactly match a "spa" redirect URI registered in Azure
  return window.location.origin;
}

function generateCodeVerifier(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, b => b.toString(36).padStart(2, '0')).join('').slice(0, 64);
}

async function generateCodeChallenge(verifier: string): Promise<string> {
  const encoder = new TextEncoder();
  const hash = await crypto.subtle.digest('SHA-256', encoder.encode(verifier));
  return btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * Opens a Microsoft OAuth popup to get a Graph Calendar access token.
 * Uses the authorization code flow with PKCE, which Microsoft supports for
 * SPAs without a client secret (the redirect URI must be registered as "spa").
 */
export async function connectOutlookCalendar(): Promise<string> {
  if (Platform.OS !== 'web') {
    throw new Error('Use expo-auth-session for native');
  }
  if (!isOutlookConfigured()) {
    throw new Error('Outlook is not configured yet');
  }

  const codeVerifier = generateCodeVerifier();
  const codeChallenge = await generateCodeChallenge(codeVerifier);
  const state = Math.random().toString(36).substring(2);
  const redirectUri = getRedirectUri();

  const params = new URLSearchParams({
    client_id: OUTLOOK_CLIENT_ID,
    redirect_uri: redirectUri,
    response_type: 'code',
    response_mode: 'query',
    scope: GRAPH_SCOPE,
    state,
    prompt: 'select_account',
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  });

  const authUrl = `${AUTHORITY}/oauth2/v2.0/authorize?${params}`;
  const width = 500;
  const height = 640;
  const left = window.screenX + (window.innerWidth - width) / 2;
  const top = window.screenY + (window.innerHeight - height) / 2;

  return new Promise((resolve, reject) => {
    const popup = window.open(
      authUrl,
      'outlook-calendar-auth',
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
            reject(new Error(`Microsoft auth error: ${error}`));
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

          try {
            const tokenRes = await fetch(`${AUTHORITY}/oauth2/v2.0/token`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
              body: new URLSearchParams({
                client_id: OUTLOOK_CLIENT_ID,
                code,
                code_verifier: codeVerifier,
                grant_type: 'authorization_code',
                redirect_uri: redirectUri,
                scope: GRAPH_SCOPE,
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

    setTimeout(() => {
      clearInterval(interval);
      if (!popup.closed) popup.close();
      reject(new Error('Auth timed out'));
    }, 300000);
  });
}
