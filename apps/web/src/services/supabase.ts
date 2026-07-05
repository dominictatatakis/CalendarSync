import { createClient } from '@supabase/supabase-js';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';
import { AppUser, Friend, FriendGroup, Friendship, EventInvite, SharedEvent } from '../types';

const SUPABASE_URL = 'https://legodplyxrcpougmglgs.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_Fcs9f-wizlxBHmZEDUFLHg_ucegRuyV';

// Use SecureStore on native, localStorage on web
const ExpoSecureStoreAdapter = {
  getItem: (key: string) => {
    if (Platform.OS === 'web') return localStorage.getItem(key);
    return SecureStore.getItemAsync(key);
  },
  setItem: (key: string, value: string) => {
    if (Platform.OS === 'web') { localStorage.setItem(key, value); return Promise.resolve(); }
    return SecureStore.setItemAsync(key, value);
  },
  removeItem: (key: string) => {
    if (Platform.OS === 'web') { localStorage.removeItem(key); return Promise.resolve(); }
    return SecureStore.deleteItemAsync(key);
  },
};

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: ExpoSecureStoreAdapter as any,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: Platform.OS === 'web',
  },
});

// MARK: - Auth

export async function sendOTP(email: string): Promise<void> {
  const { error } = await supabase.auth.signInWithOtp({ email });
  if (error) throw error;
}

export async function verifyOTP(email: string, token: string): Promise<AppUser> {
  const { data, error } = await supabase.auth.verifyOtp({ email, token, type: 'email' });
  if (error) throw error;
  const uid = data.user!.id;
  const userEmail = data.user!.email ?? email;
  return upsertProfile(uid, userEmail);
}

export async function signInWithGoogle(): Promise<void> {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: Platform.OS === 'web' ? window.location.origin : 'calendarsync://auth' },
  });
  if (error) throw error;
}

export async function signOut(): Promise<void> {
  await supabase.auth.signOut();
}

export async function getCurrentUser(): Promise<AppUser | null> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return null;
  return fetchProfile(session.user.id).catch(() => null);
}

// MARK: - Profiles

async function upsertProfile(id: string, email: string): Promise<AppUser> {
  const displayName = email.split('@')[0];
  await supabase.from('profiles').upsert({ id, email, display_name: displayName }, { onConflict: 'id' });
  return fetchProfile(id);
}

async function fetchProfile(id: string): Promise<AppUser> {
  const { data, error } = await supabase.from('profiles').select().eq('id', id).single();
  if (error) throw error;
  return { id: data.id, email: data.email, displayName: data.display_name, avatarUrl: data.avatar_url };
}

export async function findUserByEmail(email: string): Promise<AppUser | null> {
  const { data } = await supabase.from('profiles').select().eq('email', email).maybeSingle();
  if (!data) return null;
  return { id: data.id, email: data.email, displayName: data.display_name, avatarUrl: data.avatar_url };
}

export async function updateDisplayName(userId: string, name: string): Promise<void> {
  await supabase.from('profiles').update({ display_name: name }).eq('id', userId);
}

export async function findUsersByEmails(emails: string[]): Promise<AppUser[]> {
  if (emails.length === 0) return [];
  const { data } = await supabase.from('profiles').select().in('email', emails);
  return (data ?? []).map(r => ({ id: r.id, email: r.email, displayName: r.display_name, avatarUrl: r.avatar_url }));
}

// MARK: - Friends

export async function sendFriendRequest(fromId: string, toId: string): Promise<void> {
  const { error } = await supabase.from('friendships').insert({ requester_id: fromId, addressee_id: toId, status: 'pending' });
  if (error) throw error;
}

export async function acceptFriendRequest(friendshipId: string): Promise<void> {
  await supabase.from('friendships').update({ status: 'accepted' }).eq('id', friendshipId);
}

export async function fetchFriends(userId: string): Promise<Friend[]> {
  const { data: rows } = await supabase
    .from('friendships')
    .select()
    .eq('status', 'accepted')
    .or(`requester_id.eq.${userId},addressee_id.eq.${userId}`);

  if (!rows) return [];
  const friends: Friend[] = [];
  for (const row of rows) {
    const friendId = row.requester_id === userId ? row.addressee_id : row.requester_id;
    const profile = await fetchProfile(friendId).catch(() => null);
    if (profile) friends.push({ id: row.id, user: profile, groups: [] });
  }
  return friends;
}

export async function fetchPendingRequests(userId: string): Promise<Friendship[]> {
  const { data } = await supabase.from('friendships').select().eq('addressee_id', userId).eq('status', 'pending');
  return (data ?? []).map(r => ({ id: r.id, requesterId: r.requester_id, addresseeId: r.addressee_id, status: r.status }));
}

// MARK: - Groups

export async function fetchGroups(ownerId: string): Promise<FriendGroup[]> {
  const { data: groups } = await supabase.from('groups').select().eq('owner_id', ownerId);
  if (!groups) return [];
  const result: FriendGroup[] = [];
  for (const g of groups) {
    const { data: members } = await supabase.from('group_members').select('user_id').eq('group_id', g.id);
    result.push({ id: g.id, name: g.name, memberIds: (members ?? []).map((m: any) => m.user_id) });
  }
  return result;
}

export async function createGroup(ownerId: string, name: string): Promise<FriendGroup> {
  const { data, error } = await supabase.from('groups').insert({ owner_id: ownerId, name }).select().single();
  if (error) throw error;
  return { id: data.id, name: data.name, memberIds: [] };
}

// MARK: - Shared Events & Invites

export async function createSharedEvent(event: Omit<SharedEvent, 'id'>): Promise<SharedEvent> {
  const { data, error } = await supabase.from('shared_events').insert({
    organizer_id: event.organizerId,
    organizer_name: event.organizerName,
    title: event.title,
    start_date: event.startDate.toISOString(),
    end_date: event.endDate.toISOString(),
    location: event.location,
    notes: event.notes,
  }).select().single();
  if (error) throw error;
  return { ...event, id: data.id };
}

export async function sendInvite(eventId: string, inviteeId: string, inviteeEmail: string): Promise<void> {
  await supabase.from('event_invites').insert({ event_id: eventId, invitee_id: inviteeId, invitee_email: inviteeEmail });
}

export async function fetchMyInvites(userId: string): Promise<EventInvite[]> {
  const { data } = await supabase
    .from('event_invites')
    .select('*, shared_events(*)')
    .eq('invitee_id', userId)
    .eq('status', 'pending');
  if (!data) return [];
  return data.map((row: any) => ({
    id: row.id,
    eventId: row.event_id,
    inviteeId: row.invitee_id,
    status: row.status,
    event: row.shared_events ? {
      id: row.shared_events.id,
      organizerId: row.shared_events.organizer_id,
      organizerName: row.shared_events.organizer_name,
      title: row.shared_events.title,
      startDate: new Date(row.shared_events.start_date),
      endDate: new Date(row.shared_events.end_date),
      location: row.shared_events.location,
    } : undefined,
  }));
}

export async function respondToInvite(inviteId: string, accept: boolean): Promise<void> {
  await supabase.from('event_invites').update({ status: accept ? 'accepted' : 'declined' }).eq('id', inviteId);
}
