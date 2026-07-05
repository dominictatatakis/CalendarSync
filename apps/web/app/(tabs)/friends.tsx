import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  FlatList, Alert, ActivityIndicator, Modal, ScrollView,
} from 'react-native';
import { useFriends } from '../../src/contexts/FriendsContext';
import { respondToInvite } from '../../src/services/supabase';
import { EventInvite, Friend, Friendship } from '../../src/types';
import CreateEventModal from '../../src/components/CreateEventModal';
import FriendAvailability from '../../src/components/FriendAvailability';
import ImportContactsModal from '../../src/components/ImportContactsModal';

export default function FriendsScreen() {
  const { friends, pendingRequests, invites, isLoading, load, addFriend, acceptRequest } = useFriends();
  const [addEmail, setAddEmail] = useState('');
  const [isAdding, setIsAdding] = useState(false);
  const [selectedInvite, setSelectedInvite] = useState<EventInvite | null>(null);
  const [showCreateEvent, setShowCreateEvent] = useState(false);
  const [selectedFriend, setSelectedFriend] = useState<Friend | null>(null);
  const [showImportContacts, setShowImportContacts] = useState(false);

  const handleAddFriend = async () => {
    if (!addEmail.trim()) return;
    setIsAdding(true);
    try {
      await addFriend(addEmail.trim().toLowerCase());
      setAddEmail('');
      Alert.alert('Request sent!', `Friend request sent to ${addEmail}`);
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setIsAdding(false);
    }
  };

  const handleRespond = async (inviteId: string, accept: boolean) => {
    await respondToInvite(inviteId, accept);
    setSelectedInvite(null);
    await load();
  };

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.pageHeader}>Friends</Text>
      {/* Add friend */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Add a Friend</Text>
        <View style={styles.addRow}>
          <TextInput
            style={styles.input}
            placeholder="friend@example.com"
            placeholderTextColor="#999"
            value={addEmail}
            onChangeText={setAddEmail}
            keyboardType="email-address"
            autoCapitalize="none"
          />
          <TouchableOpacity style={styles.addBtn} onPress={handleAddFriend} disabled={isAdding}>
            {isAdding ? <ActivityIndicator color="#fff" size="small" /> : <Text style={styles.addBtnText}>Add</Text>}
          </TouchableOpacity>
        </View>
        <TouchableOpacity style={styles.importBtn} onPress={() => setShowImportContacts(true)}>
          <Text style={styles.importBtnText}>Import from Instagram or WhatsApp</Text>
        </TouchableOpacity>
      </View>

      {/* Pending requests */}
      {pendingRequests.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Friend Requests</Text>
          {pendingRequests.map(req => (
            <RequestRow key={req.id} request={req} onAccept={() => acceptRequest(req.id)} />
          ))}
        </View>
      )}

      {/* Event invites */}
      {invites.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Event Invites</Text>
          {invites.map(invite => (
            <InviteRow key={invite.id} invite={invite} onPress={() => setSelectedInvite(invite)} />
          ))}
        </View>
      )}

      {/* Create event */}
      <View style={styles.section}>
        <TouchableOpacity style={styles.createEventBtn} onPress={() => setShowCreateEvent(true)}>
          <Text style={styles.createEventText}>+ Create Shared Event</Text>
        </TouchableOpacity>
      </View>

      {/* Friends list */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Friends ({friends.length})</Text>
        {isLoading ? (
          <ActivityIndicator />
        ) : friends.length === 0 ? (
          <Text style={styles.empty}>No friends yet — add someone above</Text>
        ) : (
          friends.map(f => (
            <TouchableOpacity key={f.id} onPress={() => setSelectedFriend(f)}>
              <FriendRow friend={f} />
            </TouchableOpacity>
          ))
        )}
      </View>

      {/* Import contacts modal */}
      <ImportContactsModal visible={showImportContacts} onClose={() => setShowImportContacts(false)} />

      {/* Create event modal */}
      <CreateEventModal visible={showCreateEvent} onClose={() => setShowCreateEvent(false)} />

      {/* Friend availability modal */}
      <Modal visible={!!selectedFriend} animationType="slide" presentationStyle="pageSheet">
        {selectedFriend && (
          <FriendAvailability friend={selectedFriend} onClose={() => setSelectedFriend(null)} />
        )}
      </Modal>

      {/* Invite detail modal */}
      <Modal visible={!!selectedInvite} animationType="slide" presentationStyle="pageSheet">
        {selectedInvite && (
          <InviteDetail
            invite={selectedInvite}
            onAccept={() => handleRespond(selectedInvite.id, true)}
            onDecline={() => handleRespond(selectedInvite.id, false)}
            onClose={() => setSelectedInvite(null)}
          />
        )}
      </Modal>
    </ScrollView>
  );
}

function RequestRow({ request, onAccept }: { request: Friendship; onAccept: () => void }) {
  return (
    <View style={styles.row}>
      <View style={styles.avatar}><Text style={styles.avatarText}>👤</Text></View>
      <View style={styles.rowInfo}>
        <Text style={styles.rowTitle}>Friend request</Text>
        <Text style={styles.rowSub}>{request.requesterId}</Text>
      </View>
      <TouchableOpacity style={styles.acceptBtn} onPress={onAccept}>
        <Text style={styles.acceptBtnText}>Accept</Text>
      </TouchableOpacity>
    </View>
  );
}

function InviteRow({ invite, onPress }: { invite: EventInvite; onPress: () => void }) {
  return (
    <TouchableOpacity style={styles.row} onPress={onPress}>
      <View style={styles.avatar}><Text style={styles.avatarText}>📨</Text></View>
      <View style={styles.rowInfo}>
        <Text style={styles.rowTitle}>{invite.event?.title ?? 'Event invite'}</Text>
        <Text style={styles.rowSub}>From {invite.event?.organizerName ?? 'someone'}</Text>
      </View>
      <Text style={styles.chevron}>›</Text>
    </TouchableOpacity>
  );
}

function FriendRow({ friend }: { friend: Friend }) {
  const initials = friend.user.displayName.slice(0, 2).toUpperCase();
  return (
    <View style={styles.row}>
      <View style={styles.avatar}><Text style={styles.avatarInitials}>{initials}</Text></View>
      <View style={styles.rowInfo}>
        <Text style={styles.rowTitle}>{friend.user.displayName}</Text>
        <Text style={styles.rowSub}>{friend.user.email}</Text>
      </View>
      <Text style={styles.chevron}>&#8250;</Text>
    </View>
  );
}

function InviteDetail({ invite, onAccept, onDecline, onClose }: {
  invite: EventInvite; onAccept: () => void; onDecline: () => void; onClose: () => void;
}) {
  const e = invite.event;
  return (
    <View style={styles.modalContainer}>
      <TouchableOpacity style={styles.modalClose} onPress={onClose}>
        <Text style={styles.modalCloseText}>✕</Text>
      </TouchableOpacity>
      <Text style={styles.modalTitle}>{e?.title ?? 'Event Invite'}</Text>
      {e && (
        <>
          <Text style={styles.modalMeta}>From {e.organizerName}</Text>
          <Text style={styles.modalMeta}>
            {e.startDate.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
          </Text>
          <Text style={styles.modalMeta}>
            {e.startDate.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })} –{' '}
            {e.endDate.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
          </Text>
          {e.location && <Text style={styles.modalMeta}>📍 {e.location}</Text>}
        </>
      )}
      <View style={styles.modalActions}>
        <TouchableOpacity style={styles.acceptLarge} onPress={onAccept}>
          <Text style={styles.acceptLargeText}>✓ Accept</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.declineLarge} onPress={onDecline}>
          <Text style={styles.declineLargeText}>✕ Decline</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f8f8f8' },
  pageHeader: { fontSize: 22, fontWeight: '700', color: '#1c1c1e', paddingHorizontal: 16, paddingTop: 20, paddingBottom: 8 },
  section: { backgroundColor: '#fff', marginBottom: 12, padding: 16 },
  sectionTitle: { fontSize: 13, fontWeight: '700', color: '#888', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 },
  addRow: { flexDirection: 'row', gap: 8 },
  input: { flex: 1, borderWidth: 1, borderColor: '#e0e0e0', borderRadius: 10, padding: 12, fontSize: 15, color: '#111', backgroundColor: '#fafafa' },
  addBtn: { backgroundColor: '#007AFF', borderRadius: 10, paddingHorizontal: 18, justifyContent: 'center' },
  addBtnText: { color: '#fff', fontWeight: '600' },
  row: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8 },
  avatar: { width: 42, height: 42, borderRadius: 21, backgroundColor: '#e8e8e8', alignItems: 'center', justifyContent: 'center', marginRight: 12 },
  avatarText: { fontSize: 20 },
  avatarInitials: { fontSize: 16, fontWeight: '700', color: '#555' },
  rowInfo: { flex: 1 },
  rowTitle: { fontSize: 15, fontWeight: '600', color: '#111' },
  rowSub: { fontSize: 13, color: '#888', marginTop: 1 },
  acceptBtn: { backgroundColor: '#34c759', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 6 },
  acceptBtnText: { color: '#fff', fontWeight: '600', fontSize: 13 },
  chevron: { fontSize: 22, color: '#ccc' },
  importBtn: { marginTop: 8, borderWidth: 1, borderColor: '#007AFF', borderRadius: 10, padding: 12, alignItems: 'center' },
  importBtnText: { color: '#007AFF', fontWeight: '600', fontSize: 14 },
  createEventBtn: { backgroundColor: '#007AFF', borderRadius: 10, padding: 14, alignItems: 'center' },
  createEventText: { color: '#fff', fontWeight: '600', fontSize: 15 },
  empty: { color: '#aaa', fontSize: 14, textAlign: 'center', paddingVertical: 12 },
  modalContainer: { flex: 1, padding: 24, paddingTop: 60 },
  modalClose: { position: 'absolute', top: 20, right: 20, padding: 8 },
  modalCloseText: { fontSize: 18, color: '#888' },
  modalTitle: { fontSize: 24, fontWeight: '700', color: '#111', marginBottom: 16 },
  modalMeta: { fontSize: 15, color: '#555', marginBottom: 8 },
  modalActions: { flexDirection: 'row', gap: 12, marginTop: 32 },
  acceptLarge: { flex: 1, backgroundColor: '#34c759', borderRadius: 12, padding: 16, alignItems: 'center' },
  acceptLargeText: { color: '#fff', fontWeight: '700', fontSize: 16 },
  declineLarge: { flex: 1, backgroundColor: '#ff3b30', borderRadius: 12, padding: 16, alignItems: 'center' },
  declineLargeText: { color: '#fff', fontWeight: '700', fontSize: 16 },
});
