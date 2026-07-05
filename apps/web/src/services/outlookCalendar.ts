import { CalendarEvent } from '../types';

const GRAPH_API = 'https://graph.microsoft.com/v1.0';
const OUTLOOK_COLOR = '#0078D4';

/**
 * Fetches Outlook events in a date range via the Graph calendarView endpoint,
 * mapped into the app's unified CalendarEvent shape.
 */
export async function fetchOutlookCalendarEvents(
  accessToken: string,
  startDate: Date,
  endDate: Date,
): Promise<CalendarEvent[]> {
  const params = new URLSearchParams({
    startDateTime: startDate.toISOString(),
    endDateTime: endDate.toISOString(),
    $top: '250',
    $orderby: 'start/dateTime',
    $select: 'id,subject,start,end,isAllDay,location',
  });

  const res = await fetch(`${GRAPH_API}/me/calendarView?${params}`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      // Return event times in UTC so we can parse them unambiguously
      Prefer: 'outlook.timezone="UTC"',
    },
  });
  if (!res.ok) {
    throw new Error(`Outlook API error ${res.status}`);
  }
  const json = await res.json();
  const items: any[] = json.value ?? [];

  const events: CalendarEvent[] = [];
  for (const item of items) {
    if (!item.id || !item.start?.dateTime || !item.end?.dateTime) continue;
    events.push({
      id: `outlook-${item.id}`,
      title: item.subject || '(No title)',
      // Graph returns naive datetimes in the requested timezone (UTC)
      startDate: new Date(`${item.start.dateTime}Z`),
      endDate: new Date(`${item.end.dateTime}Z`),
      isAllDay: !!item.isAllDay,
      source: 'outlook',
      calendarName: 'Outlook',
      color: OUTLOOK_COLOR,
      location: item.location?.displayName || undefined,
    });
  }
  return events.sort((a, b) => a.startDate.getTime() - b.startDate.getTime());
}
