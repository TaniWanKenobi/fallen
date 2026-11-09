<script lang="ts" module>
  // `team` when the main huddle is full and the link goes to their team's instead.
  export interface Huddle {
    url: string | null
    team: boolean
  }
</script>

<script lang="ts">
  import { events } from '@/lib/events'
  import SettingRow from '@/components/settings/SettingRow.svelte'
  import { formatMinutes } from '@/lib/format'

  // Events run in the main huddle, which stays open between them for anyone working.
  let { huddle }: { huddle?: Huddle } = $props()
  const huddleUrl = $derived(huddle?.url)

  const dayLabel = new Intl.DateTimeFormat(undefined, { weekday: 'short', timeZone: 'UTC' })
  const dateLabel = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric', timeZone: 'UTC' })
  const localDate = new Intl.DateTimeFormat('en-CA')
  const timeRange = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' })
  // Some locales write "p.m."; the calendar always says AM and PM.
  const joinParts = (parts: Intl.DateTimeFormatPart[]) =>
    parts
      .map((part) => (part.type === 'dayPeriod' ? part.value.replaceAll('.', '').toUpperCase() : part.value))
      .join('')
  const formatRange = (start: Date, end: Date) => joinParts(timeRange.formatRangeToParts(start, end))

  const sorted = events
    .map((event) => ({ ...event, startsAt: new Date(event.start), endsAt: new Date(event.end) }))
    .sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime())
  const keyOf = (date: Date) => localDate.format(date)
  const addDays = (key: string, n: number) => {
    const date = new Date(`${key}T00:00:00Z`)
    date.setUTCDate(date.getUTCDate() + n)
    return date
  }

  // In development, ?now=2026-11-10T11:00-05:00 runs the calendar's clock from that moment, to see each state.
  const fakeNow = import.meta.env.DEV
    ? Date.parse(new URLSearchParams(location.search).get('now') ?? '')
    : NaN
  const offset = Number.isNaN(fakeNow) ? 0 : fakeNow - Date.now()
  let now = $state(Date.now() + offset)
  $effect(() => {
    const timer = setInterval(() => (now = Date.now() + offset), 30_000)
    return () => clearInterval(timer)
  })
  const today = $derived(keyOf(new Date(now)))
  const liveEvent = $derived(
    sorted.find((event) => event.startsAt.getTime() <= now && event.endsAt.getTime() > now),
  )
  const nextToday = $derived(
    sorted.find((event) => event.startsAt.getTime() > now && keyOf(event.startsAt) === today),
  )
  const minutesUntil = (date: Date) => Math.max(1, Math.ceil((date.getTime() - now) / 60_000))
  const endedAgo = (date: Date) => {
    const minutes = Math.floor((now - date.getTime()) / 60_000)
    if (minutes < 1) return 'Ended just now'
    if (minutes < 24 * 60) return `Ended ${formatMinutes(minutes)} ago`
    const days = Math.floor(minutes / (24 * 60))
    return `Ended ${days} ${days === 1 ? 'day' : 'days'} ago`
  }
  // A week in Eastern can spill onto an eighth local day, so the span follows the events.
  const first = keyOf(sorted[0]?.startsAt ?? new Date())
  const last = keyOf(sorted.at(-1)?.startsAt ?? new Date())
  const span = Math.max(7, Math.round((Date.parse(last) - Date.parse(first)) / 86_400_000) + 1)
  const days = Array.from({ length: span }, (_, i) => {
    const date = addDays(first, i)
    const key = date.toISOString().slice(0, 10)
    return {
      key,
      weekday: dayLabel.format(date),
      label: dateLabel.format(date),
      events: sorted.filter((event) => keyOf(event.startsAt) === key),
    }
  })
</script>

<section class="glass" aria-labelledby="events">
  <div class="flex flex-wrap items-baseline justify-between gap-x-4 pr-5 md:pr-6">
    <h2 id="events" class="glass-heading">Events</h2>
    <p class="font-outfit text-xs text-sky-ice/50">Your local time</p>
  </div>
  {#if huddleUrl}
    <div class="border-t border-white/10">
      {#if liveEvent}
        <SettingRow
          title="{liveEvent.title} is on now · {formatMinutes(minutesUntil(liveEvent.endsAt))} left"
          description={huddle?.team
            ? "The main huddle is full right now, so this takes you to your team's huddle."
            : "It's happening in the huddle. Jump in!"}
        >
          <a
            href={huddleUrl}
            target="_blank"
            rel="noopener"
            class="pill-glass border-saffron bg-saffron text-slate-ink hover:bg-saffron hover:brightness-110"
            >Join huddle ↗</a
          >
        </SettingRow>
      {:else}
        <SettingRow
          title={nextToday
            ? `${nextToday.title} starts in ${formatMinutes(minutesUntil(nextToday.startsAt))}`
            : 'No event on right now'}
          description={huddle?.team
            ? "The main huddle is full right now, so this takes you to your team's huddle to work alongside your team."
            : 'The huddle is always open, so you can hop in and work alongside other people.'}
        >
          <a href={huddleUrl} target="_blank" rel="noopener" class="pill-glass">Join huddle ↗</a>
        </SettingRow>
      {/if}
    </div>
  {/if}
  <!-- Every day draws its right and bottom border; the outer ones are clipped so only the dividers show. -->
  <div class="overflow-hidden border-t border-white/10">
    <ol
      class="-mr-px -mb-px grid grid-cols-2 sm:grid-cols-4 xl:grid-cols-[repeat(var(--days),minmax(0,1fr))]"
      style:--days={days.length}
    >
      {#each days as day (day.key)}
        {@const isToday = day.key === today}
        <li
          class={[
            'flex min-w-0 flex-col gap-2 border-r border-b border-white/10 px-3 py-4 transition-colors duration-700 hover:duration-150 sm:px-4',
            isToday ? 'hover:bg-white/15' : 'hover:bg-white/5',
            isToday && 'bg-white/10 shadow-[inset_0_2px_0_var(--color-saffron)]',
          ]}
          aria-current={isToday ? 'date' : undefined}
        >
          <p
            class="flex flex-wrap items-center gap-x-1.5 gap-y-1 font-montserrat text-sm font-semibold text-white"
          >
            {day.weekday}
            <span class={['font-outfit font-normal', isToday ? 'text-saffron' : 'text-sky-ice/60']}
              >{day.label}</span
            >
          </p>
          {#each day.events as event (event.start + event.title)}
            {@const ended = event.endsAt.getTime() <= now}
            {@const live = !ended && event.startsAt.getTime() <= now}
            <div
              class={[
                'rounded-[4px] px-2.5 py-2 wrap-anywhere sm:px-3',
                ended && 'bg-white/10 opacity-70',
                live &&
                  'bg-saffron/10 shadow-[0_0_14px_-6px_var(--color-saffron)] ring-2 ring-saffron/70 ring-inset',
                !ended && !live && isToday && 'bg-white/10 ring-1 ring-saffron/40 ring-inset',
                !ended && !live && !isToday && 'bg-white/10',
              ]}
            >
              <p class="font-montserrat text-sm font-semibold text-white">
                {event.title}
                {#if event.note}<span class="font-normal text-sky-ice/70">{event.note}</span>{/if}
              </p>
              <p class={['font-outfit text-xs text-sky-ice/70', ended && 'line-through']}>
                {formatRange(event.startsAt, event.endsAt)}
              </p>
              {#if event.host}<p class="font-outfit text-xs text-sky-ice/50">Run by @{event.host}</p>{/if}
              {#if ended}
                <p class="mt-1 font-outfit text-xs font-semibold text-sky-ice">{endedAgo(event.endsAt)}</p>
              {:else if live}
                <p class="mt-1 flex items-center gap-1.5 font-outfit text-xs font-semibold text-saffron">
                  <span class="size-2 shrink-0 animate-pulse rounded-full bg-saffron" aria-hidden="true"
                  ></span>
                  Happening now · {formatMinutes(minutesUntil(event.endsAt))} left
                </p>
              {:else if isToday}
                <p class="mt-1 font-outfit text-xs font-semibold text-saffron">
                  Starts in {formatMinutes(minutesUntil(event.startsAt))}
                </p>
              {/if}
            </div>
          {:else}
            <p class="font-outfit text-xs text-sky-ice/40">Nothing scheduled</p>
          {/each}
        </li>
      {/each}
    </ol>
  </div>
</section>
