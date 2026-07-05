import { CalendarEvent } from '../types';

const CALENDAR_API = 'https://www.googleapis.com/calendar/v3';

/**
 * Fetch events from specific Google Calendars (or all if no filter provided).
 */
export async function fetchGoogleCalendarEvents(
  accessToken: string,
  startDate: Date,
  endDate: Date,
  enabledCalendarIds?: string[] | null
): Promise<CalendarEvent[]> {
  // Fetch calendar list
  const listRes = await fetch(
    `${CALENDAR_API}/users/me/calendarList?minAccessRole=reader`,
    { headers: { Authorization: `Bearer ${accessToken}` } }
  );
  const listJson = await listRes.json();
  const calendars: Array<{ id: string; summary: string; backgroundColor: string }> =
    listJson.items ?? [];

  // Filter to only enabled calendars if a list is provided
  const activeCals = enabledCalendarIds
    ? calendars.filter(c => enabledCalendarIds.includes(c.id))
    : calendars;

  const allEvents: CalendarEvent[] = [];

  await Promise.all(
    activeCals.map(async (cal) => {
      const params = new URLSearchParams({
        timeMin: startDate.toISOString(),
        timeMax: endDate.toISOString(),
        singleEvents: 'true',
        orderBy: 'startTime',
        maxResults: '250',
      });
      const eventsRes = await fetch(
        `${CALENDAR_API}/calendars/${encodeURIComponent(cal.id)}/events?${params}`,
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );
      const eventsJson = await eventsRes.json();
      const items: any[] = eventsJson.items ?? [];

      for (const item of items) {
        const isAllDay = !!item.start?.date;
        const startStr = item.start?.date ?? item.start?.dateTime;
        const endStr = item.end?.date ?? item.end?.dateTime;
        if (!item.id || !item.summary || !startStr || !endStr) continue;

        allEvents.push({
          id: `google-${item.id}`,
          title: item.summary,
          startDate: new Date(startStr),
          endDate: new Date(endStr),
          isAllDay,
          source: 'google',
          calendarName: cal.summary,
          color: cal.backgroundColor ?? '#4285F4',
        });
      }
    })
  );

  return allEvents.sort((a, b) => a.startDate.getTime() - b.startDate.getTime());
}
