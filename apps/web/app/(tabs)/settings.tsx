import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, Alert, Platform } from 'react-native';
import { useAuth } from '../../src/contexts/AuthContext';
import { connectGoogleCalendar } from '../../src/services/googleAuth';

export default function SettingsScreen() {
  const {
    user, googleAccessToken, googleCalendars, enabledCalendarIds,
    setGoogleAccessToken, setEnabledCalendarIds, logout,
  } = useAuth();

  const handleConnectGoogle = async () => {
    try {
      const token = await connectGoogleCalendar();
      setGoogleAccessToken(token);
    } catch (e: any) {
      if (e.message !== 'Auth cancelled') {
        Alert.alert('Error', e.message);
      }
    }
  };

  const handleDisconnectGoogle = () => {
    setGoogleAccessToken(null);
  };

  const toggleCalendar = (calId: string) => {
    if (enabledCalendarIds.includes(calId)) {
      setEnabledCalendarIds(enabledCalendarIds.filter(id => id !== calId));
    } else {
      setEnabledCalendarIds([...enabledCalendarIds, calId]);
    }
  };

  const handleSignOut = () => {
    if (Platform.OS === 'web') {
      if (confirm('Sign out?')) logout();
    } else {
      Alert.alert('Sign out', 'Are you sure?', [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Sign out', style: 'destructive', onPress: logout },
      ]);
    }
  };

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.header}>Settings</Text>

      {/* Profile */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Account</Text>
        <View style={styles.profileRow}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>{user?.displayName?.slice(0, 2).toUpperCase() ?? '?'}</Text>
          </View>
          <View>
            <Text style={styles.profileName}>{user?.displayName}</Text>
            <Text style={styles.profileEmail}>{user?.email}</Text>
          </View>
        </View>
      </View>

      {/* Calendar connections */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Connected Accounts</Text>

        <View style={styles.row}>
          <View style={styles.rowLeft}>
            <View style={[styles.calIcon, { backgroundColor: '#4285F4' }]}>
              <Text style={styles.calIconText}>G</Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.rowLabel}>Google Calendar</Text>
              <Text style={styles.rowSub}>
                {googleAccessToken
                  ? `${googleCalendars.length} calendar${googleCalendars.length !== 1 ? 's' : ''} available`
                  : 'Sync your Google events'}
              </Text>
            </View>
          </View>
          {googleAccessToken ? (
            <TouchableOpacity style={styles.disconnectBtn} onPress={handleDisconnectGoogle}>
              <Text style={styles.disconnectBtnText}>Disconnect</Text>
            </TouchableOpacity>
          ) : (
            <TouchableOpacity style={styles.connectBtn} onPress={handleConnectGoogle}>
              <Text style={styles.connectBtnText}>Connect</Text>
            </TouchableOpacity>
          )}
        </View>

        <View style={[styles.row, styles.rowDisabled]}>
          <View style={styles.rowLeft}>
            <View style={[styles.calIcon, { backgroundColor: '#0078D4' }]}>
              <Text style={styles.calIconText}>O</Text>
            </View>
            <View>
              <Text style={styles.rowLabel}>Outlook Calendar</Text>
              <Text style={styles.rowSub}>Coming soon</Text>
            </View>
          </View>
        </View>
      </View>

      {/* Individual calendar toggles */}
      {googleAccessToken && googleCalendars.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Google Calendars</Text>
          <Text style={styles.sectionHint}>Choose which calendars to display</Text>
          {googleCalendars.map(cal => {
            const isEnabled = enabledCalendarIds.includes(cal.id);
            return (
              <TouchableOpacity
                key={cal.id}
                style={styles.calRow}
                onPress={() => toggleCalendar(cal.id)}
              >
                <View style={[styles.calColorDot, { backgroundColor: cal.color }]} />
                <View style={styles.calInfo}>
                  <Text style={styles.calName}>{cal.name}</Text>
                  {cal.primary && <Text style={styles.calBadge}>Primary</Text>}
                </View>
                <View style={[styles.checkbox, isEnabled && styles.checkboxChecked]}>
                  {isEnabled && <Text style={styles.checkmark}>{'\u2713'}</Text>}
                </View>
              </TouchableOpacity>
            );
          })}
        </View>
      )}

      {/* Sign out */}
      <TouchableOpacity style={styles.signOutBtn} onPress={handleSignOut}>
        <Text style={styles.signOutText}>Sign out</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f7' },
  header: { fontSize: 22, fontWeight: '700', color: '#1c1c1e', paddingHorizontal: 20, paddingTop: 20, paddingBottom: 8 },
  section: { backgroundColor: '#fff', marginBottom: 8, paddingHorizontal: 16, paddingTop: 8, paddingBottom: 4 },
  sectionTitle: { fontSize: 11, fontWeight: '700', color: '#8e8e93', textTransform: 'uppercase', letterSpacing: 0.5, paddingVertical: 8 },
  sectionHint: { fontSize: 12, color: '#8e8e93', marginBottom: 8 },
  profileRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12, gap: 14 },
  avatar: { width: 48, height: 48, borderRadius: 24, backgroundColor: '#4F46E5', alignItems: 'center', justifyContent: 'center' },
  avatarText: { color: '#fff', fontSize: 17, fontWeight: '700' },
  profileName: { fontSize: 16, fontWeight: '600', color: '#1c1c1e' },
  profileEmail: { fontSize: 13, color: '#8e8e93', marginTop: 2 },
  row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 12, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#e5e5ea' },
  rowDisabled: { opacity: 0.45 },
  rowLeft: { flexDirection: 'row', alignItems: 'center', gap: 12, flex: 1 },
  calIcon: { width: 32, height: 32, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  calIconText: { color: '#fff', fontWeight: '700', fontSize: 15 },
  rowLabel: { fontSize: 15, fontWeight: '500', color: '#1c1c1e' },
  rowSub: { fontSize: 12, color: '#8e8e93', marginTop: 1 },
  connectBtn: { backgroundColor: '#4F46E5', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 7 },
  connectBtnText: { color: '#fff', fontWeight: '600', fontSize: 13 },
  disconnectBtn: { borderWidth: 1, borderColor: '#ff3b30', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 6 },
  disconnectBtnText: { color: '#ff3b30', fontWeight: '600', fontSize: 13 },

  // Calendar toggles
  calRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#f0f0f0',
  },
  calColorDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 12,
  },
  calInfo: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8 },
  calName: { fontSize: 14, fontWeight: '500', color: '#1c1c1e' },
  calBadge: { fontSize: 10, color: '#8e8e93', backgroundColor: '#f2f2f7', borderRadius: 4, paddingHorizontal: 6, paddingVertical: 1, overflow: 'hidden' },
  checkbox: {
    width: 22,
    height: 22,
    borderRadius: 6,
    borderWidth: 1.5,
    borderColor: '#d1d1d6',
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxChecked: {
    backgroundColor: '#4F46E5',
    borderColor: '#4F46E5',
  },
  checkmark: { color: '#fff', fontSize: 13, fontWeight: '700' },

  signOutBtn: { margin: 16, backgroundColor: '#fff', borderRadius: 12, padding: 14, alignItems: 'center' },
  signOutText: { color: '#ff3b30', fontWeight: '600', fontSize: 15 },
});
