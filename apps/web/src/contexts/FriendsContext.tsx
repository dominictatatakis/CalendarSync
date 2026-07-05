import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import {
  fetchFriends, fetchPendingRequests, fetchGroups,
  sendFriendRequest, acceptFriendRequest, findUserByEmail,
  fetchMyInvites, respondToInvite,
} from '../services/supabase';
import { Friend, Friendship, FriendGroup, EventInvite } from '../types';
import { useAuth } from './AuthContext';

interface FriendsContextType {
  friends: Friend[];
  pendingRequests: Friendship[];
  groups: FriendGroup[];
  invites: EventInvite[];
  isLoading: boolean;
  load: () => Promise<void>;
  addFriend: (email: string) => Promise<void>;
  acceptRequest: (id: string) => Promise<void>;
}

const FriendsContext = createContext<FriendsContextType | null>(null);

export function FriendsProvider({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  const [friends, setFriends] = useState<Friend[]>([]);
  const [pendingRequests, setPendingRequests] = useState<Friendship[]>([]);
  const [groups, setGroups] = useState<FriendGroup[]>([]);
  const [invites, setInvites] = useState<EventInvite[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const load = useCallback(async () => {
    if (!user) return;
    setIsLoading(true);
    try {
      const [f, p, g, i] = await Promise.all([
        fetchFriends(user.id),
        fetchPendingRequests(user.id),
        fetchGroups(user.id),
        fetchMyInvites(user.id),
      ]);
      setFriends(f);
      setPendingRequests(p);
      setGroups(g);
      setInvites(i);
    } finally {
      setIsLoading(false);
    }
  }, [user]);

  useEffect(() => { load(); }, [load]);

  const addFriend = async (email: string) => {
    if (!user) return;
    const found = await findUserByEmail(email);
    if (!found) throw new Error('No user found with that email');
    await sendFriendRequest(user.id, found.id);
    await load();
  };

  const acceptRequest = async (friendshipId: string) => {
    await acceptFriendRequest(friendshipId);
    await load();
  };

  return (
    <FriendsContext.Provider value={{ friends, pendingRequests, groups, invites, isLoading, load, addFriend, acceptRequest }}>
      {children}
    </FriendsContext.Provider>
  );
}

export function useFriends() {
  const ctx = useContext(FriendsContext);
  if (!ctx) throw new Error('useFriends must be used within FriendsProvider');
  return ctx;
}
