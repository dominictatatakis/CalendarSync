export type CalendarSource = 'google' | 'outlook' | 'apple';

export interface CalendarEvent {
  id: string;
  title: string;
  startDate: Date;
  endDate: Date;
  isAllDay: boolean;
  source: CalendarSource;
  calendarName: string;
  color: string;
  location?: string;
}

export interface AppUser {
  id: string;
  email: string;
  displayName: string;
  avatarUrl?: string;
}

export interface Friend {
  id: string;
  user: AppUser;
  groups: string[];
}

export type FriendshipStatus = 'pending' | 'accepted' | 'declined';

export interface Friendship {
  id: string;
  requesterId: string;
  addresseeId: string;
  status: FriendshipStatus;
}

export interface FriendGroup {
  id: string;
  name: string;
  memberIds: string[];
}

export interface SharedEvent {
  id: string;
  organizerId: string;
  organizerName: string;
  title: string;
  startDate: Date;
  endDate: Date;
  location?: string;
  notes?: string;
}

export interface EventInvite {
  id: string;
  eventId: string;
  inviteeId: string;
  status: 'pending' | 'accepted' | 'declined';
  event?: SharedEvent;
}

export interface GoogleCalendarInfo {
  id: string;
  name: string;
  color: string;
  primary: boolean;
  selected: boolean;
}

export type ContactSource = 'instagram' | 'whatsapp' | 'phone';

export interface ImportedContact {
  name: string;
  email?: string;
  phone?: string;
  source: ContactSource;
  avatarUrl?: string;
  matchedUser?: AppUser; // populated if they're already on CalendarSync
}
