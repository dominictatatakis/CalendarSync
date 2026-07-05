import React, { createContext, useContext, useEffect, useState } from 'react';
import { supabase, sendOTP, verifyOTP, signOut, getCurrentUser } from '../services/supabase';
import { fetchGoogleCalendarList, GoogleCalendarInfo } from '../services/googleAuth';
import { AppUser } from '../types';

interface AuthContextType {
  user: AppUser | null;
  isLoading: boolean;
  error: string | null;
  googleAccessToken: string | null;
  googleCalendars: GoogleCalendarInfo[];
  enabledCalendarIds: string[];
  outlookAccessToken: string | null;
  setOutlookAccessToken: (token: string | null) => void;
  setGoogleAccessToken: (token: string | null) => void;
  setEnabledCalendarIds: (ids: string[]) => void;
  setError: (e: string | null) => void;
  sendOTPEmail: (email: string) => Promise<void>;
  verifyOTPCode: (email: string, token: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AppUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [googleAccessToken, setGoogleAccessTokenRaw] = useState<string | null>(null);
  const [googleCalendars, setGoogleCalendars] = useState<GoogleCalendarInfo[]>([]);
  const [enabledCalendarIds, setEnabledCalendarIdsRaw] = useState<string[]>([]);
  const [outlookAccessToken, setOutlookAccessToken] = useState<string | null>(null);

  // When the token changes, fetch the calendar list
  const setGoogleAccessToken = (token: string | null) => {
    setGoogleAccessTokenRaw(token);
    if (!token) {
      setGoogleCalendars([]);
      setEnabledCalendarIdsRaw([]);
      return;
    }
    // Fetch calendars and enable all by default
    fetchGoogleCalendarList(token).then(cals => {
      setGoogleCalendars(cals);
      // Restore from localStorage if available, otherwise enable all
      try {
        const stored = localStorage.getItem('cs_enabled_cals');
        if (stored) {
          const ids = JSON.parse(stored) as string[];
          // Only keep IDs that still exist
          const valid = ids.filter(id => cals.some(c => c.id === id));
          setEnabledCalendarIdsRaw(valid.length > 0 ? valid : cals.map(c => c.id));
        } else {
          setEnabledCalendarIdsRaw(cals.map(c => c.id));
        }
      } catch {
        setEnabledCalendarIdsRaw(cals.map(c => c.id));
      }
    }).catch(() => {});
  };

  const setEnabledCalendarIds = (ids: string[]) => {
    setEnabledCalendarIdsRaw(ids);
    try { localStorage.setItem('cs_enabled_cals', JSON.stringify(ids)); } catch {}
  };

  useEffect(() => {
    getCurrentUser().then(u => { setUser(u); setIsLoading(false); });

    // Check if the current session already has a Google provider token
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.provider_token) {
        setGoogleAccessToken(session.provider_token);
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (session?.user) {
        const u = await getCurrentUser();
        setUser(u);
        if (session.provider_token) {
          setGoogleAccessToken(session.provider_token);
        }
      } else {
        setUser(null);
        setGoogleAccessToken(null);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const sendOTPEmail = async (email: string) => {
    setIsLoading(true);
    setError(null);
    try {
      await sendOTP(email);
    } catch (e: any) {
      setError(e.message);
      throw e;
    } finally {
      setIsLoading(false);
    }
  };

  const verifyOTPCode = async (email: string, token: string) => {
    setIsLoading(true);
    setError(null);
    try {
      const u = await verifyOTP(email, token);
      setUser(u);
    } catch (e: any) {
      setError(e.message);
      throw e;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = async () => {
    await signOut();
    setUser(null);
    setGoogleAccessToken(null);
    setOutlookAccessToken(null);
  };

  return (
    <AuthContext.Provider value={{
      user, isLoading, error,
      googleAccessToken, googleCalendars, enabledCalendarIds,
      outlookAccessToken, setOutlookAccessToken,
      setGoogleAccessToken, setEnabledCalendarIds,
      setError, sendOTPEmail, verifyOTPCode, logout,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
