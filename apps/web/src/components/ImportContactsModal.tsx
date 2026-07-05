import React, { useState } from 'react';
import {
  View, Text, TouchableOpacity, StyleSheet,
  Modal, ScrollView, ActivityIndicator, Alert, TextInput,
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';
import { useFriends } from '../contexts/FriendsContext';
import { findUsersByEmails, sendFriendRequest } from '../services/supabase';
import { AppUser, ImportedContact, ContactSource } from '../types';

interface Props {
  visible: boolean;
  onClose: () => void;
}

export default function ImportContactsModal({ visible, onClose }: Props) {
  const { user } = useAuth();
  const { load } = useFriends();
  const [contacts, setContacts] = useState<ImportedContact[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [isImporting, setIsImporting] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const [didSend, setDidSend] = useState(false);
  const [activeSource, setActiveSource] = useState<ContactSource | null>(null);
  const [manualEmails, setManualEmails] = useState('');

  const toggleContact = (email: string) => {
    setSelectedIds(prev => {
      const next = new Set(prev);
      if (next.has(email)) next.delete(email);
      else next.add(email);
      return next;
    });
  };

  const importFromInstagram = async () => {
    setActiveSource('instagram');
    setIsImporting(true);
    try {
      // Instagram Graph API requires OAuth. In production, this would:
      // 1. Open an OAuth flow to get an Instagram access token
      // 2. Call GET /me/friends or the follower list endpoint
      // 3. Extract emails/usernames from the response
      //
      // For now, we simulate by showing a manual entry flow since Instagram
      // API access requires app review. Users paste their followers' emails.
      Alert.alert(
        'Instagram Import',
        'Instagram requires OAuth authorization. For now, paste your contacts\' email addresses in the text field below.',
      );
    } finally {
      setIsImporting(false);
    }
  };

  const importFromWhatsApp = async () => {
    setActiveSource('whatsapp');
    setIsImporting(true);
    try {
      // WhatsApp doesn't expose a public contacts API.
      // The practical approach is to read device contacts (synced from WhatsApp)
      // using expo-contacts on native, or manual entry on web.
      //
      // On native (iOS/Android), we'd use:
      //   import * as Contacts from 'expo-contacts';
      //   const { data } = await Contacts.getContactsAsync({ fields: [Contacts.Fields.Emails] });
      //
      // On web, we prompt for manual entry.
      Alert.alert(
        'WhatsApp Import',
        'On mobile, this reads your device contacts (synced from WhatsApp). On web, paste email addresses below.',
      );
    } finally {
      setIsImporting(false);
    }
  };

  const handleManualLookup = async () => {
    if (!manualEmails.trim()) return;
    setIsImporting(true);
    try {
      const emails = manualEmails
        .split(/[,\n;]+/)
        .map(e => e.trim().toLowerCase())
        .filter(e => e.includes('@'));

      const matchedUsers = await findUsersByEmails(emails);
      const matchedMap = new Map(matchedUsers.map(u => [u.email, u]));

      const imported: ImportedContact[] = emails.map(email => ({
        name: matchedMap.get(email)?.displayName ?? email.split('@')[0],
        email,
        source: activeSource ?? 'phone',
        matchedUser: matchedMap.get(email),
      }));

      setContacts(imported);
      // Auto-select matched users
      const autoSelect = new Set(imported.filter(c => c.matchedUser).map(c => c.email!));
      setSelectedIds(autoSelect);
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setIsImporting(false);
    }
  };

  const handleSendRequests = async () => {
    if (!user) return;
    setIsSending(true);
    try {
      const toSend = contacts.filter(c => selectedIds.has(c.email!) && c.matchedUser);
      for (const contact of toSend) {
        try {
          await sendFriendRequest(user.id, contact.matchedUser!.id);
        } catch (_) { /* skip duplicates */ }
      }
      setDidSend(true);
      await load();
      setTimeout(() => {
        resetState();
        onClose();
      }, 1500);
    } finally {
      setIsSending(false);
    }
  };

  const resetState = () => {
    setContacts([]);
    setSelectedIds(new Set());
    setActiveSource(null);
    setManualEmails('');
    setDidSend(false);
  };

  const matchedCount = contacts.filter(c => c.matchedUser && selectedIds.has(c.email!)).length;

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet">
      <View style={styles.container}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => { resetState(); onClose(); }}>
            <Text style={styles.cancelBtn}>Cancel</Text>
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Import Contacts</Text>
          <View style={{ width: 50 }} />
        </View>

        <ScrollView style={styles.content}>
          {/* Source selection */}
          {contacts.length === 0 && (
            <>
              <Text style={styles.sectionTitle}>Choose a Source</Text>

              <TouchableOpacity style={styles.sourceBtn} onPress={importFromInstagram}>
                <View style={[styles.sourceIcon, { backgroundColor: '#E1306C' }]}>
                  <Text style={styles.sourceIconText}>IG</Text>
                </View>
                <View>
                  <Text style={styles.sourceName}>Instagram</Text>
                  <Text style={styles.sourceSub}>Import from your followers</Text>
                </View>
              </TouchableOpacity>

              <TouchableOpacity style={styles.sourceBtn} onPress={importFromWhatsApp}>
                <View style={[styles.sourceIcon, { backgroundColor: '#25D366' }]}>
                  <Text style={styles.sourceIconText}>WA</Text>
                </View>
                <View>
                  <Text style={styles.sourceName}>WhatsApp</Text>
                  <Text style={styles.sourceSub}>Import from device contacts</Text>
                </View>
              </TouchableOpacity>

              {activeSource && (
                <>
                  <Text style={[styles.sectionTitle, { marginTop: 20 }]}>Paste Email Addresses</Text>
                  <Text style={styles.hint}>
                    Enter emails separated by commas or new lines. We'll check which ones are on CalendarSync.
                  </Text>
                  <TextInput
                    style={styles.emailInput}
                    placeholder={"friend1@example.com\nfriend2@example.com"}
                    placeholderTextColor="#999"
                    value={manualEmails}
                    onChangeText={setManualEmails}
                    multiline
                    numberOfLines={5}
                  />
                  <TouchableOpacity
                    style={[styles.lookupBtn, !manualEmails.trim() && styles.lookupBtnDisabled]}
                    onPress={handleManualLookup}
                    disabled={!manualEmails.trim() || isImporting}
                  >
                    {isImporting ? (
                      <ActivityIndicator color="#fff" size="small" />
                    ) : (
                      <Text style={styles.lookupBtnText}>Find Contacts</Text>
                    )}
                  </TouchableOpacity>
                </>
              )}
            </>
          )}

          {/* Contact list */}
          {contacts.length > 0 && (
            <>
              <Text style={styles.sectionTitle}>
                Found {contacts.filter(c => c.matchedUser).length} of {contacts.length} on CalendarSync
              </Text>

              {contacts.map((contact, i) => {
                const isMatched = !!contact.matchedUser;
                const isSelected = selectedIds.has(contact.email!);
                return (
                  <TouchableOpacity
                    key={i}
                    style={[styles.contactRow, !isMatched && styles.contactRowDimmed]}
                    onPress={() => isMatched && toggleContact(contact.email!)}
                    disabled={!isMatched}
                  >
                    <View style={[styles.checkbox, isSelected && isMatched && styles.checkboxSelected]}>
                      {isSelected && isMatched && <Text style={styles.checkmark}>&#10003;</Text>}
                    </View>
                    <View style={styles.contactInfo}>
                      <Text style={styles.contactName}>{contact.name}</Text>
                      <Text style={styles.contactEmail}>{contact.email}</Text>
                    </View>
                    {isMatched ? (
                      <View style={styles.matchBadge}>
                        <Text style={styles.matchBadgeText}>On CalendarSync</Text>
                      </View>
                    ) : (
                      <Text style={styles.notFoundText}>Not found</Text>
                    )}
                  </TouchableOpacity>
                );
              })}

              {didSend ? (
                <View style={styles.successBanner}>
                  <Text style={styles.successText}>Friend requests sent!</Text>
                </View>
              ) : (
                <TouchableOpacity
                  style={[styles.sendBtn, matchedCount === 0 && styles.sendBtnDisabled]}
                  onPress={handleSendRequests}
                  disabled={matchedCount === 0 || isSending}
                >
                  {isSending ? (
                    <ActivityIndicator color="#fff" size="small" />
                  ) : (
                    <Text style={styles.sendBtnText}>
                      Send {matchedCount} Friend Request{matchedCount !== 1 ? 's' : ''}
                    </Text>
                  )}
                </TouchableOpacity>
              )}
            </>
          )}
        </ScrollView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f8f8f8' },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    padding: 16, paddingTop: 20, backgroundColor: '#fff', borderBottomWidth: 1, borderBottomColor: '#f0f0f0',
  },
  headerTitle: { fontSize: 17, fontWeight: '600', color: '#111' },
  cancelBtn: { color: '#4F46E5', fontSize: 16 },
  content: { padding: 16 },
  sectionTitle: { fontSize: 13, fontWeight: '700', color: '#888', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 },
  hint: { fontSize: 13, color: '#888', marginBottom: 8, lineHeight: 18 },
  sourceBtn: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff',
    padding: 14, borderRadius: 12, marginBottom: 8, gap: 14,
  },
  sourceIcon: {
    width: 44, height: 44, borderRadius: 12, alignItems: 'center', justifyContent: 'center',
  },
  sourceIconText: { color: '#fff', fontWeight: '800', fontSize: 16 },
  sourceName: { fontSize: 16, fontWeight: '600', color: '#111' },
  sourceSub: { fontSize: 13, color: '#888', marginTop: 1 },
  emailInput: {
    borderWidth: 1, borderColor: '#e0e0e0', borderRadius: 10, padding: 12,
    fontSize: 14, backgroundColor: '#fff', color: '#111', minHeight: 100,
    textAlignVertical: 'top', marginBottom: 12,
  },
  lookupBtn: { backgroundColor: '#4F46E5', borderRadius: 10, padding: 14, alignItems: 'center' },
  lookupBtnDisabled: { backgroundColor: '#ccc' },
  lookupBtnText: { color: '#fff', fontWeight: '600', fontSize: 15 },
  contactRow: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff',
    padding: 12, borderRadius: 10, marginBottom: 6, gap: 12,
  },
  contactRowDimmed: { opacity: 0.5 },
  checkbox: {
    width: 24, height: 24, borderRadius: 12, borderWidth: 2,
    borderColor: '#ccc', alignItems: 'center', justifyContent: 'center',
  },
  checkboxSelected: { backgroundColor: '#4F46E5', borderColor: '#4F46E5' },
  checkmark: { color: '#fff', fontSize: 14, fontWeight: '700' },
  contactInfo: { flex: 1 },
  contactName: { fontSize: 15, fontWeight: '500', color: '#111' },
  contactEmail: { fontSize: 13, color: '#888', marginTop: 1 },
  matchBadge: { backgroundColor: '#d4edda', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6 },
  matchBadgeText: { color: '#155724', fontSize: 11, fontWeight: '600' },
  notFoundText: { color: '#aaa', fontSize: 12 },
  sendBtn: { backgroundColor: '#34c759', borderRadius: 12, padding: 16, alignItems: 'center', marginTop: 16 },
  sendBtnDisabled: { backgroundColor: '#ccc' },
  sendBtnText: { color: '#fff', fontWeight: '700', fontSize: 16 },
  successBanner: { backgroundColor: '#d4edda', padding: 12, borderRadius: 10, marginTop: 16, alignItems: 'center' },
  successText: { color: '#155724', fontWeight: '600', fontSize: 15 },
});
