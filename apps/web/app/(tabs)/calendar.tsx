import React, { useState, useEffect } from 'react';
import {
  View, Text, ScrollView, TouchableOpacity, StyleSheet,
  ActivityIndicator, useWindowDimensions,
} from 'react-native';
import { CalendarEvent } from '../../src/types';
import { fetchGoogleCalendarEvents } from '../../src/services/googleCalendar';
import { useAuth } from '../../src/contexts/AuthContext';

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

type ViewMode = 'month' | 'week' | 'day';

const HOURS = Array.from({ length: 24 }, (_, i) => i);

export default function CalendarScreen() {
  const { googleAccessToken, enabledCalendarIds } = useAuth();
  const { width } = useWindowDimensions();
  const isDesktop = width >= 768;
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [viewMode, setViewMode] = useState<ViewMode>('month');
  const [events, setEvents] = useState<CalendarEvent[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => { loadEvents(); }, [currentMonth, googleAccessToken, enabledCalendarIds]);

  const loadEvents = async () => {
    setIsLoading(true);
    try {
      const start = new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1, 1);
      const end = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 3, 0);
      let allEvents: CalendarEvent[] = [];
      if (googleAccessToken) {
        const ge = await fetchGoogleCalendarEvents(googleAccessToken, start, end, enabledCalendarIds.length > 0 ? enabledCalendarIds : null);
        allEvents = [...allEvents, ...ge];
      }
      setEvents(allEvents.sort((a, b) => a.startDate.getTime() - b.startDate.getTime()));
    } finally {
      setIsLoading(false);
    }
  };

  const eventsOnDay = (date: Date) => events.filter(e => isSameDay(e.startDate, date));

  const handleToday = () => {
    const now = new Date();
    setSelectedDate(now);
    setCurrentMonth(now);
  };

  return (
    <View style={styles.container}>
      {/* Toolbar */}
      <View style={[styles.toolbar, isDesktop && styles.toolbarDesktop]}>
        <View style={styles.toolbarLeft}>
          <TouchableOpacity style={styles.todayBtn} onPress={handleToday}>
            <Text style={styles.todayBtnText}>Today</Text>
          </TouchableOpacity>
          <View style={styles.navRow}>
            <TouchableOpacity onPress={() => navigate(-1)} style={styles.navArrow}>
              <Text style={styles.navArrowText}>{'\u2039'}</Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => navigate(1)} style={styles.navArrow}>
              <Text style={styles.navArrowText}>{'\u203A'}</Text>
            </TouchableOpacity>
          </View>
          <Text style={styles.toolbarTitle}>{getToolbarTitle()}</Text>
        </View>
        <View style={styles.viewToggle}>
          {(['month', 'week', 'day'] as ViewMode[]).map(mode => (
            <TouchableOpacity
              key={mode}
              style={[styles.viewBtn, viewMode === mode && styles.viewBtnActive]}
              onPress={() => setViewMode(mode)}
            >
              <Text style={[styles.viewBtnText, viewMode === mode && styles.viewBtnTextActive]}>
                {mode.charAt(0).toUpperCase() + mode.slice(1)}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Content */}
      {isLoading && <ActivityIndicator style={{ margin: 12 }} />}

      {viewMode === 'month' && (
        <MonthView
          currentMonth={currentMonth}
          selectedDate={selectedDate}
          events={events}
          isDesktop={isDesktop}
          onSelectDate={(d) => setSelectedDate(d)}
          eventsOnDay={eventsOnDay}
        />
      )}

      {viewMode === 'week' && (
        <WeekView
          selectedDate={selectedDate}
          events={events}
          isDesktop={isDesktop}
          onSelectDate={setSelectedDate}
        />
      )}

      {viewMode === 'day' && (
        <DayView
          selectedDate={selectedDate}
          events={events}
          isDesktop={isDesktop}
        />
      )}

      {!googleAccessToken && (
        <View style={styles.connectBanner}>
          <Text style={styles.connectText}>Connect Google Calendar in Settings to see your events</Text>
        </View>
      )}
    </View>
  );

  function navigate(dir: number) {
    if (viewMode === 'month') {
      setCurrentMonth(m => addMonths(m, dir));
    } else if (viewMode === 'week') {
      setSelectedDate(d => addDays(d, dir * 7));
      setCurrentMonth(addDays(selectedDate, dir * 7));
    } else {
      setSelectedDate(d => addDays(d, dir));
      setCurrentMonth(addDays(selectedDate, dir));
    }
  }

  function getToolbarTitle(): string {
    if (viewMode === 'month') {
      return `${MONTHS[currentMonth.getMonth()]} ${currentMonth.getFullYear()}`;
    }
    if (viewMode === 'week') {
      const weekStart = getWeekStart(selectedDate);
      const weekEnd = addDays(weekStart, 6);
      if (weekStart.getMonth() === weekEnd.getMonth()) {
        return `${MONTHS[weekStart.getMonth()]} ${weekStart.getDate()}\u2013${weekEnd.getDate()}, ${weekStart.getFullYear()}`;
      }
      return `${MONTHS[weekStart.getMonth()].slice(0, 3)} ${weekStart.getDate()} \u2013 ${MONTHS[weekEnd.getMonth()].slice(0, 3)} ${weekEnd.getDate()}, ${weekEnd.getFullYear()}`;
    }
    return selectedDate.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });
  }
}

/* ── Month View ── */
function MonthView({ currentMonth, selectedDate, events, isDesktop, onSelectDate, eventsOnDay }: {
  currentMonth: Date; selectedDate: Date; events: CalendarEvent[];
  isDesktop: boolean; onSelectDate: (d: Date) => void; eventsOnDay: (d: Date) => CalendarEvent[];
}) {
  const calendarDays = getCalendarDays(currentMonth);
  const selectedDayEvents = eventsOnDay(selectedDate);

  return (
    <View style={isDesktop ? styles.monthDesktopLayout : styles.monthMobileLayout}>
      <View style={isDesktop ? styles.monthGridDesktop : styles.monthGridMobile}>
        {/* Day labels */}
        <View style={styles.dayLabels}>
          {DAYS.map(d => <Text key={d} style={[styles.dayLabel, isDesktop && styles.dayLabelDesktop]}>{d}</Text>)}
        </View>

        {/* Grid */}
        <View style={styles.grid}>
          {calendarDays.map((day, i) => {
            const isToday = day && isSameDay(day, new Date());
            const isSelected = day && isSameDay(day, selectedDate);
            const dayEvents = day ? eventsOnDay(day) : [];
            return (
              <TouchableOpacity
                key={i}
                style={[
                  styles.cell,
                  isDesktop && styles.cellDesktop,
                  isSelected && styles.cellSelected,
                ]}
                onPress={() => day && onSelectDate(day)}
                disabled={!day}
              >
                <Text style={[
                  styles.cellText,
                  isDesktop && styles.cellTextDesktop,
                  isToday && styles.cellToday,
                  isSelected && styles.cellSelectedText,
                ]}>
                  {day?.getDate() ?? ''}
                </Text>
                {dayEvents.length > 0 && (
                  <View style={[styles.dot, isSelected && styles.dotSelected]} />
                )}
              </TouchableOpacity>
            );
          })}
        </View>
      </View>

      {/* Event list */}
      <View style={isDesktop ? styles.eventPanelDesktop : styles.eventPanelMobile}>
        <Text style={styles.selectedDateLabel}>
          {selectedDate.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
        </Text>
        {selectedDayEvents.length === 0 ? (
          <Text style={styles.noEvents}>No events</Text>
        ) : (
          <ScrollView>
            {selectedDayEvents.map(event => (
              <EventRow key={event.id} event={event} />
            ))}
          </ScrollView>
        )}
      </View>
    </View>
  );
}

/* ── Week View ── */
function WeekView({ selectedDate, events, isDesktop, onSelectDate }: {
  selectedDate: Date; events: CalendarEvent[]; isDesktop: boolean; onSelectDate: (d: Date) => void;
}) {
  const weekStart = getWeekStart(selectedDate);
  const weekDays = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));

  return (
    <ScrollView style={styles.weekContainer}>
      {/* Day headers */}
      <View style={styles.weekHeader}>
        <View style={styles.timeGutter} />
        {weekDays.map((day, i) => {
          const isToday = isSameDay(day, new Date());
          const isSelected = isSameDay(day, selectedDate);
          return (
            <TouchableOpacity
              key={i}
              style={[styles.weekDayHeader, isSelected && styles.weekDayHeaderActive]}
              onPress={() => onSelectDate(day)}
            >
              <Text style={[styles.weekDayName, isToday && styles.weekDayToday]}>
                {DAYS[day.getDay()]}
              </Text>
              <Text style={[
                styles.weekDayNum,
                isToday && styles.weekDayNumToday,
                isSelected && styles.weekDayNumSelected,
              ]}>
                {day.getDate()}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>

      {/* Time grid */}
      {HOURS.map(hour => (
        <View key={hour} style={styles.weekRow}>
          <View style={styles.timeGutter}>
            <Text style={styles.timeLabel}>{formatHour(hour)}</Text>
          </View>
          {weekDays.map((day, di) => {
            const cellEvents = events.filter(e =>
              isSameDay(e.startDate, day) && !e.isAllDay && e.startDate.getHours() === hour
            );
            return (
              <View key={di} style={styles.weekCell}>
                {cellEvents.map(e => (
                  <View key={e.id} style={[styles.weekEvent, { backgroundColor: e.color || '#007AFF' }]}>
                    <Text style={styles.weekEventText} numberOfLines={1}>{e.title}</Text>
                    <Text style={styles.weekEventTime}>{fmtTime(e.startDate)}</Text>
                  </View>
                ))}
              </View>
            );
          })}
        </View>
      ))}
    </ScrollView>
  );
}

/* ── Day View ── */
function DayView({ selectedDate, events, isDesktop }: {
  selectedDate: Date; events: CalendarEvent[]; isDesktop: boolean;
}) {
  const dayEvents = events.filter(e => isSameDay(e.startDate, selectedDate));
  const allDayEvents = dayEvents.filter(e => e.isAllDay);
  const timedEvents = dayEvents.filter(e => !e.isAllDay);

  return (
    <ScrollView style={styles.dayContainer}>
      {/* All-day events */}
      {allDayEvents.length > 0 && (
        <View style={styles.allDaySection}>
          <Text style={styles.allDayLabel}>All Day</Text>
          {allDayEvents.map(e => (
            <View key={e.id} style={[styles.allDayEvent, { borderLeftColor: e.color || '#007AFF' }]}>
              <Text style={styles.allDayEventText}>{e.title}</Text>
            </View>
          ))}
        </View>
      )}

      {/* Hour slots */}
      {HOURS.map(hour => {
        const hourEvents = timedEvents.filter(e => e.startDate.getHours() === hour);
        return (
          <View key={hour} style={styles.dayRow}>
            <View style={styles.dayTimeGutter}>
              <Text style={styles.timeLabel}>{formatHour(hour)}</Text>
            </View>
            <View style={styles.daySlot}>
              {hourEvents.map(e => (
                <View key={e.id} style={[styles.dayEvent, { borderLeftColor: e.color || '#007AFF' }]}>
                  <Text style={styles.dayEventTitle}>{e.title}</Text>
                  <Text style={styles.dayEventMeta}>
                    {fmtTime(e.startDate)} {'\u2013'} {fmtTime(e.endDate)}
                    {e.location ? ` \u00b7 ${e.location}` : ''}
                  </Text>
                </View>
              ))}
            </View>
          </View>
        );
      })}
    </ScrollView>
  );
}

/* ── Shared components ── */
function EventRow({ event }: { event: CalendarEvent }) {
  const timeStr = event.isAllDay
    ? 'All day'
    : `${fmtTime(event.startDate)} \u2013 ${fmtTime(event.endDate)}`;

  return (
    <View style={styles.eventRow}>
      <View style={[styles.eventColor, { backgroundColor: event.color || '#007AFF' }]} />
      <View style={styles.eventInfo}>
        <Text style={styles.eventTitle}>{event.title}</Text>
        <Text style={styles.eventMeta}>{timeStr} {'\u00b7'} {event.calendarName}</Text>
      </View>
    </View>
  );
}

/* ── Helpers ── */
function fmtTime(d: Date) {
  return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
}

function formatHour(h: number): string {
  if (h === 0) return '12 AM';
  if (h < 12) return `${h} AM`;
  if (h === 12) return '12 PM';
  return `${h - 12} PM`;
}

function isSameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function addMonths(date: Date, n: number): Date {
  const d = new Date(date);
  d.setMonth(d.getMonth() + n);
  return d;
}

function addDays(date: Date, n: number): Date {
  const d = new Date(date);
  d.setDate(d.getDate() + n);
  return d;
}

function getWeekStart(date: Date): Date {
  const d = new Date(date);
  d.setDate(d.getDate() - d.getDay());
  return d;
}

function getCalendarDays(month: Date): (Date | null)[] {
  const first = new Date(month.getFullYear(), month.getMonth(), 1);
  const last = new Date(month.getFullYear(), month.getMonth() + 1, 0);
  const days: (Date | null)[] = Array(first.getDay()).fill(null);
  for (let d = 1; d <= last.getDate(); d++) {
    days.push(new Date(month.getFullYear(), month.getMonth(), d));
  }
  while (days.length % 7 !== 0) days.push(null);
  return days;
}

/* ── Styles ── */
const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },

  // Toolbar
  toolbar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#e5e5ea',
    flexWrap: 'wrap',
    gap: 8,
  },
  toolbarDesktop: { paddingHorizontal: 24 },
  toolbarLeft: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  todayBtn: {
    borderWidth: 1,
    borderColor: '#d1d1d6',
    borderRadius: 6,
    paddingHorizontal: 12,
    paddingVertical: 5,
  },
  todayBtnText: { fontSize: 13, fontWeight: '600', color: '#333' },
  navRow: { flexDirection: 'row', gap: 2 },
  navArrow: { paddingHorizontal: 6, paddingVertical: 2 },
  navArrowText: { fontSize: 22, color: '#555', fontWeight: '300' },
  toolbarTitle: { fontSize: 16, fontWeight: '700', color: '#1c1c1e', marginLeft: 4 },
  viewToggle: {
    flexDirection: 'row',
    backgroundColor: '#f2f2f7',
    borderRadius: 8,
    padding: 2,
  },
  viewBtn: { paddingHorizontal: 14, paddingVertical: 6, borderRadius: 6 },
  viewBtnActive: { backgroundColor: '#fff', shadowColor: '#000', shadowOpacity: 0.08, shadowRadius: 4, shadowOffset: { width: 0, height: 1 } },
  viewBtnText: { fontSize: 13, color: '#8e8e93', fontWeight: '500' },
  viewBtnTextActive: { color: '#1c1c1e', fontWeight: '600' },

  // Month view
  monthDesktopLayout: { flex: 1, flexDirection: 'row' },
  monthMobileLayout: { flex: 1 },
  monthGridDesktop: { flex: 1, maxWidth: 520, padding: 16, borderRightWidth: StyleSheet.hairlineWidth, borderRightColor: '#e5e5ea' },
  monthGridMobile: { paddingHorizontal: 8, paddingTop: 8 },
  dayLabels: { flexDirection: 'row', paddingHorizontal: 4 },
  dayLabel: { flex: 1, textAlign: 'center', fontSize: 11, color: '#8e8e93', fontWeight: '600', paddingBottom: 6 },
  dayLabelDesktop: { fontSize: 11 },
  grid: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 4 },
  cell: {
    width: '14.28%',
    aspectRatio: 1,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 100,
  },
  cellDesktop: { maxWidth: 64, maxHeight: 64 },
  cellSelected: { backgroundColor: '#007AFF' },
  cellText: { fontSize: 14, color: '#1c1c1e' },
  cellTextDesktop: { fontSize: 13 },
  cellToday: { fontWeight: '700', color: '#007AFF' },
  cellSelectedText: { color: '#fff', fontWeight: '700' },
  dot: { width: 4, height: 4, borderRadius: 2, backgroundColor: '#007AFF', marginTop: 1 },
  dotSelected: { backgroundColor: '#fff' },

  // Event panel
  eventPanelDesktop: { flex: 1, padding: 20, minWidth: 280 },
  eventPanelMobile: { flex: 1, paddingHorizontal: 16, paddingTop: 8 },
  selectedDateLabel: { fontSize: 14, fontWeight: '600', color: '#555', marginBottom: 12 },
  noEvents: { textAlign: 'center', color: '#8e8e93', marginTop: 24, fontSize: 14 },
  eventRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#f0f0f0' },
  eventColor: { width: 3, height: 36, borderRadius: 2, marginRight: 12 },
  eventInfo: { flex: 1 },
  eventTitle: { fontSize: 14, fontWeight: '600', color: '#1c1c1e' },
  eventMeta: { fontSize: 12, color: '#8e8e93', marginTop: 2 },

  connectBanner: { backgroundColor: '#fff8e1', padding: 12, margin: 12, borderRadius: 8 },
  connectText: { color: '#b45309', fontSize: 13, textAlign: 'center' },

  // Week view
  weekContainer: { flex: 1 },
  weekHeader: { flexDirection: 'row', borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#e5e5ea', paddingBottom: 8 },
  weekDayHeader: { flex: 1, alignItems: 'center', paddingVertical: 6, borderRadius: 8 },
  weekDayHeaderActive: { backgroundColor: '#f2f2f7' },
  weekDayName: { fontSize: 11, color: '#8e8e93', fontWeight: '600' },
  weekDayToday: { color: '#007AFF' },
  weekDayNum: { fontSize: 20, fontWeight: '600', color: '#1c1c1e', marginTop: 2 },
  weekDayNumToday: { color: '#007AFF' },
  weekDayNumSelected: { color: '#fff', backgroundColor: '#007AFF', borderRadius: 20, width: 32, height: 32, textAlign: 'center', lineHeight: 32, overflow: 'hidden' },
  weekRow: { flexDirection: 'row', minHeight: 48, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#f0f0f0' },
  weekCell: { flex: 1, borderLeftWidth: StyleSheet.hairlineWidth, borderLeftColor: '#f0f0f0', padding: 2 },
  weekEvent: { borderRadius: 4, padding: 3, marginBottom: 1 },
  weekEventText: { color: '#fff', fontSize: 11, fontWeight: '600' },
  weekEventTime: { color: 'rgba(255,255,255,0.8)', fontSize: 10 },
  timeGutter: { width: 52, alignItems: 'flex-end', paddingRight: 8, justifyContent: 'flex-start', paddingTop: 2 },
  timeLabel: { fontSize: 10, color: '#8e8e93', fontWeight: '500' },

  // Day view
  dayContainer: { flex: 1 },
  allDaySection: { padding: 12, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#e5e5ea', backgroundColor: '#fafafa' },
  allDayLabel: { fontSize: 11, color: '#8e8e93', fontWeight: '600', marginBottom: 6 },
  allDayEvent: { backgroundColor: '#f0f4ff', borderLeftWidth: 3, borderRadius: 4, padding: 8, marginBottom: 4 },
  allDayEventText: { fontSize: 13, fontWeight: '600', color: '#1c1c1e' },
  dayRow: { flexDirection: 'row', minHeight: 52, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#f0f0f0' },
  dayTimeGutter: { width: 60, alignItems: 'flex-end', paddingRight: 10, paddingTop: 4 },
  daySlot: { flex: 1, borderLeftWidth: StyleSheet.hairlineWidth, borderLeftColor: '#e5e5ea', padding: 4 },
  dayEvent: { backgroundColor: '#f0f4ff', borderLeftWidth: 3, borderRadius: 6, padding: 8, marginBottom: 4 },
  dayEventTitle: { fontSize: 14, fontWeight: '600', color: '#1c1c1e' },
  dayEventMeta: { fontSize: 12, color: '#8e8e93', marginTop: 2 },
});
