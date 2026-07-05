import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  Modal, ScrollView, ActivityIndicator, Platform,
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';
import { useFriends } from '../contexts/FriendsContext';
import { createSharedEvent, sendInvite } from '../services/supabase';
import { Friend } from '../types';

interface Props {
  visible: boolean;
  onClose: () => void;
}

export default function CreateEventModal({ visible, onClose }: Props) {
  const { user } = useAuth();
  const { friends, load } = useFriends();

  const [title, setTitle] = useState('');
  const [location, setLocation] = useState('');
  const [notes, setNotes] = useState('');
  const [startDate, setStartDate] = useState('');
  const [startTime, setStartTime] = useState('');
  const [endDate, setEndDate] = useState('');
  const [endTime, setEndTime] = useState('');
  const [selectedFriends, setSelectedFriends] = useState<Set<string>>(new Set());
  const [isSending, setIsSending] = useState(false);
  const [didSend, setDidSend] = useState(false);

  const toggleFriend = (id: string) => {
    setSelectedFriends(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const canSend = title.trim() && startDate && startTime && endDate && endTime && selectedFriends.size > 0;

  const handleSend = async () => {
    if (!user || !canSend) return;
    setIsSending(true);
    try {
      const start = new Date(`${startDate}T${startTime}`);
      const end = new Date(`${endDate}T${endTime}`);

      const event = await createSharedEvent({
        organizerId: user.id,
        organizerName: user.displayName,
        title: title.trim(),
        startDate: start,
        endDate: end,
        location: location.trim() || undefined,
        notes: notes.trim() || undefined,
      });

      for (const friendId of selectedFriends) {
        const friend = friends.find(f => f.user.id === friendId);
        await sendInvite(event.id, friendId, friend?.user.email ?? '');
      }

      setDidSend(true);
      await load();
      setTimeout(() => {
        resetForm();
        onClose();
      }, 1500);
    } catch (e: any) {
      console.error('Failed to create event:', e);
    } finally {
      setIsSending(false);
    }
  };

  const resetForm = () => {
    setTitle('');
    setLocation('');
    setNotes('');
    setStartDate('');
    setStartTime('');
    setEndDate('');
    setEndTime('');
    setSelectedFriends(new Set());
    setDidSend(false);
  };

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet">
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => { resetForm(); onClose(); }}>
            <Text style={styles.cancelBtn}>Cancel</Text>
          </TouchableOpacity>
          <Text style={styles.headerTitle}>New Event</Text>
          <TouchableOpacity onPress={handleSend} disabled={!canSend || isSending}>
            {isSending ? (
              <ActivityIndicator size="small" />
            ) : (
              <Text style={[styles.sendBtn, !canSend && styles.sendBtnDisabled]}>Send</Text>
            )}
          </TouchableOpacity>
        </View>

        <ScrollView style={styles.form}>
          {/* Event details */}
          <Text style={styles.sectionTitle}>Event Details</Text>
          <TextInput
            style={styles.input}
            placeholder="Title"
            placeholderTextColor="#999"
            value={title}
            onChangeText={setTitle}
          />
          <TextInput
            style={styles.input}
            placeholder="Location (optional)"
            placeholderTextColor="#999"
            value={location}
            onChangeText={setLocation}
          />

          <View style={styles.dateRow}>
            <View style={styles.dateField}>
              <Text style={styles.dateLabel}>Start date</Text>
              {Platform.OS === 'web' ? (
                <input
                  type="date"
                  value={startDate}
                  onChange={(e: any) => setStartDate(e.target.value)}
                  style={webInputStyle}
                />
              ) : (
                <TextInput style={styles.input} placeholder="YYYY-MM-DD" placeholderTextColor="#999" value={startDate} onChangeText={setStartDate} />
              )}
            </View>
            <View style={styles.dateField}>
              <Text style={styles.dateLabel}>Start time</Text>
              {Platform.OS === 'web' ? (
                <input
                  type="time"
                  value={startTime}
                  onChange={(e: any) => setStartTime(e.target.value)}
                  style={webInputStyle}
                />
              ) : (
                <TextInput style={styles.input} placeholder="HH:MM" placeholderTextColor="#999" value={startTime} onChangeText={setStartTime} />
              )}
            </View>
          </View>

          <View style={styles.dateRow}>
            <View style={styles.dateField}>
              <Text style={styles.dateLabel}>End date</Text>
              {Platform.OS === 'web' ? (
                <input
                  type="date"
                  value={endDate}
                  onChange={(e: any) => setEndDate(e.target.value)}
                  style={webInputStyle}
                />
              ) : (
                <TextInput style={styles.input} placeholder="YYYY-MM-DD" placeholderTextColor="#999" value={endDate} onChangeText={setEndDate} />
              )}
            </View>
            <View style={styles.dateField}>
              <Text style={styles.dateLabel}>End time</Text>
              {Platform.OS === 'web' ? (
                <input
                  type="time"
                  value={endTime}
                  onChange={(e: any) => setEndTime(e.target.value)}
                  style={webInputStyle}
                />
              ) : (
                <TextInput style={styles.input} placeholder="HH:MM" placeholderTextColor="#999" value={endTime} onChangeText={setEndTime} />
              )}
            </View>
          </View>

          <TextInput
            style={[styles.input, styles.textArea]}
            placeholder="Notes (optional)"
            placeholderTextColor="#999"
            value={notes}
            onChangeText={setNotes}
            multiline
            numberOfLines={3}
          />

          {/* Friend selection */}
          <Text style={styles.sectionTitle}>Invite Friends</Text>
          {friends.length === 0 ? (
            <Text style={styles.empty}>No friends to invite yet</Text>
          ) : (
            friends.map((friend: Friend) => {
              const isSelected = selectedFriends.has(friend.user.id);
              return (
                <TouchableOpacity
                  key={friend.id}
                  style={[styles.friendRow, isSelected && styles.friendRowSelected]}
                  onPress={() => toggleFriend(friend.user.id)}
                >
                  <View style={[styles.checkbox, isSelected && styles.checkboxSelected]}>
                    {isSelected && <Text style={styles.checkmark}>&#10003;</Text>}
                  </View>
                  <View>
                    <Text style={styles.friendName}>{friend.user.displayName}</Text>
                    <Text style={styles.friendEmail}>{friend.user.email}</Text>
                  </View>
                </TouchableOpacity>
              );
            })
          )}

          {didSend && (
            <View style={styles.successBanner}>
              <Text style={styles.successText}>Invites sent!</Text>
            </View>
          )}
        </ScrollView>
      </View>
    </Modal>
  );
}

const webInputStyle = {
  fontSize: 15,
  padding: 12,
  borderWidth: 1,
  borderColor: '#e0e0e0',
  borderRadius: 10,
  backgroundColor: '#fafafa',
  width: '100%',
  boxSizing: 'border-box' as const,
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f8f8f8' },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    padding: 16, paddingTop: 20, backgroundColor: '#fff', borderBottomWidth: 1, borderBottomColor: '#f0f0f0',
  },
  headerTitle: { fontSize: 17, fontWeight: '600', color: '#111' },
  cancelBtn: { color: '#007AFF', fontSize: 16 },
  sendBtn: { color: '#007AFF', fontSize: 16, fontWeight: '600' },
  sendBtnDisabled: { color: '#ccc' },
  form: { padding: 16 },
  sectionTitle: { fontSize: 13, fontWeight: '700', color: '#888', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8, marginTop: 16 },
  input: {
    borderWidth: 1, borderColor: '#e0e0e0', borderRadius: 10,
    padding: 12, fontSize: 15, backgroundColor: '#fff', color: '#111', marginBottom: 8,
  },
  textArea: { minHeight: 80, textAlignVertical: 'top' },
  dateRow: { flexDirection: 'row', gap: 8, marginBottom: 8 },
  dateField: { flex: 1 },
  dateLabel: { fontSize: 12, color: '#888', marginBottom: 4 },
  friendRow: {
    flexDirection: 'row', alignItems: 'center', padding: 12,
    backgroundColor: '#fff', borderRadius: 10, marginBottom: 6, gap: 12,
  },
  friendRowSelected: { backgroundColor: '#e8f0fe' },
  checkbox: {
    width: 24, height: 24, borderRadius: 12, borderWidth: 2,
    borderColor: '#ccc', alignItems: 'center', justifyContent: 'center',
  },
  checkboxSelected: { backgroundColor: '#007AFF', borderColor: '#007AFF' },
  checkmark: { color: '#fff', fontSize: 14, fontWeight: '700' },
  friendName: { fontSize: 15, fontWeight: '500', color: '#111' },
  friendEmail: { fontSize: 13, color: '#888', marginTop: 1 },
  empty: { color: '#aaa', fontSize: 14, textAlign: 'center', paddingVertical: 12 },
  successBanner: { backgroundColor: '#d4edda', padding: 12, borderRadius: 10, marginTop: 16, alignItems: 'center' },
  successText: { color: '#155724', fontWeight: '600', fontSize: 15 },
});
