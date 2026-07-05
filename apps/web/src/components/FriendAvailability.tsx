import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, TouchableOpacity, StyleSheet, ScrollView,
  ActivityIndicator,
} from 'react-native';
import { Friend } from '../types';
import { supabase } from '../services/supabase';
import { useAuth } from '../contexts/AuthContext';

interface AvailabilitySlot {
  id: string;
  owner_id: string;
  start_date: string;
  end_date: string;
  title: string | null;
  is_all_day: boolean;
}

interface Props {
  friend: Friend;
  onClose: () => void;
}

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export default function FriendAvailability({ friend, onClose }: Props) {
  const { user } = useAuth();
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [slots, setSlots] = useState<AvailabilitySlot[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const weekDates = getWeekDates(selectedDate);

  const loadSlots = useCallback(async () => {
    if (!user) return;
    setIsLoading(true);
    try {
      const dayStart = startOfDay(selectedDate);
      const dayEnd = new Date(dayStart);
      dayEnd.setDate(dayEnd.getDate() + 1);

      const { data } = await supabase.rpc('get_availability', {
        friend_id: friend.user.id,
        viewer_id: user.id,
        range_start: dayStart.toISOString(),
        range_end: dayEnd.toISOString(),
      });
      setSlots(data ?? []);
    } catch (err) {
      console.error('Failed to load availability:', err);
      setSlots([]);
    } finally {
      setIsLoading(false);
    }
  }, [selectedDate, friend.user.id, user?.id]);

  useEffect(() => { loadSlots(); }, [loadSlots]);

  const shiftWeek = (direction: number) => {
    const d = new Date(selectedDate);
    d.setDate(d.getDate() + 7 * direction);
    setSelectedDate(d);
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={onClose}>
          <Text style={styles.backBtn}>&#8592; Back</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>{friend.user.displayName}</Text>
        <View style={{ width: 60 }} />
      </View>

      {/* Week strip */}
      <View style={styles.weekStrip}>
        <TouchableOpacity onPress={() => shiftWeek(-1)} style={styles.weekNav}>
          <Text style={styles.weekNavText}>&#8249;</Text>
        </TouchableOpacity>
        {weekDates.map((date, i) => {
          const isSelected = isSameDay(date, selectedDate);
          const isToday = isSameDay(date, new Date());
          return (
            <TouchableOpacity
              key={i}
              style={[styles.weekDay, isSelected && styles.weekDaySelected]}
              onPress={() => setSelectedDate(date)}
            >
              <Text style={styles.weekDayLabel}>{DAYS[date.getDay()]}</Text>
              <Text style={[
                styles.weekDayNum,
                isToday && styles.weekDayToday,
                isSelected && styles.weekDayNumSelected,
              ]}>
                {date.getDate()}
              </Text>
            </TouchableOpacity>
          );
        })}
        <TouchableOpacity onPress={() => shiftWeek(1)} style={styles.weekNav}>
          <Text style={styles.weekNavText}>&#8250;</Text>
        </TouchableOpacity>
      </View>

      {/* Date label */}
      <Text style={styles.dateLabel}>
        {selectedDate.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
      </Text>

      {/* Slots */}
      <ScrollView style={styles.slotList}>
        {isLoading ? (
          <ActivityIndicator style={{ marginTop: 24 }} />
        ) : slots.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyIcon}>&#10003;</Text>
            <Text style={styles.emptyTitle}>{friend.user.displayName} looks free</Text>
            <Text style={styles.emptySub}>No busy slots shared for this day.</Text>
          </View>
        ) : (
          slots.map((slot) => (
            <View key={slot.id} style={styles.slotRow}>
              <View style={styles.slotBar} />
              <View>
                <Text style={[styles.slotTitle, !slot.title && styles.slotTitleBusy]}>
                  {slot.title ?? 'Busy'}
                </Text>
                <Text style={styles.slotTime}>
                  {formatTime(new Date(slot.start_date))} &ndash; {formatTime(new Date(slot.end_date))}
                </Text>
              </View>
            </View>
          ))
        )}
      </ScrollView>
    </View>
  );
}

function getWeekDates(date: Date): Date[] {
  const d = new Date(date);
  const day = d.getDay();
  d.setDate(d.getDate() - day);
  return Array.from({ length: 7 }, (_, i) => {
    const wd = new Date(d);
    wd.setDate(wd.getDate() + i);
    return wd;
  });
}

function startOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate();
}

function formatTime(d: Date): string {
  return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f8f8f8' },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    padding: 16, paddingTop: 20, backgroundColor: '#fff', borderBottomWidth: 1, borderBottomColor: '#f0f0f0',
  },
  headerTitle: { fontSize: 17, fontWeight: '600', color: '#111' },
  backBtn: { color: '#4F46E5', fontSize: 16 },
  weekStrip: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff',
    paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: '#f0f0f0',
  },
  weekNav: { paddingHorizontal: 8 },
  weekNavText: { fontSize: 24, color: '#4F46E5' },
  weekDay: { flex: 1, alignItems: 'center', paddingVertical: 4 },
  weekDaySelected: { },
  weekDayLabel: { fontSize: 11, color: '#999', fontWeight: '600', textTransform: 'uppercase' },
  weekDayNum: { fontSize: 15, fontWeight: '600', color: '#111', marginTop: 4, width: 30, height: 30, textAlign: 'center', lineHeight: 30, borderRadius: 15, overflow: 'hidden' },
  weekDayToday: { color: '#4F46E5' },
  weekDayNumSelected: { backgroundColor: '#4F46E5', color: '#fff', borderRadius: 15, overflow: 'hidden' },
  dateLabel: { fontSize: 14, fontWeight: '600', color: '#555', padding: 16, paddingBottom: 8 },
  slotList: { flex: 1, paddingHorizontal: 16 },
  emptyState: { alignItems: 'center', paddingVertical: 40 },
  emptyIcon: { fontSize: 32, color: '#34c759', marginBottom: 8 },
  emptyTitle: { fontSize: 16, fontWeight: '600', color: '#111' },
  emptySub: { fontSize: 14, color: '#888', marginTop: 4 },
  slotRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, gap: 12 },
  slotBar: { width: 4, height: 36, borderRadius: 2, backgroundColor: '#9b59b6' },
  slotTitle: { fontSize: 15, fontWeight: '500', color: '#111' },
  slotTitleBusy: { color: '#888', fontStyle: 'italic' },
  slotTime: { fontSize: 13, color: '#888', marginTop: 2 },
});
