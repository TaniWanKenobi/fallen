<script lang="ts" module>
  // A week as TeamRace.weekdays sends it: each team's running totals, [h] being the XP before hour h.
  export type WeekdayWeek = { start: string; xp: Record<string, number[]> }
</script>

<script lang="ts">
  import TimeSeriesChart from '@/components/admin/TimeSeriesChart.svelte'

  // Every week laid over the others by weekday, drawn like the race's week chart: its XP as running totals from Monday
  // 00:00, an hour at a time, so where a line is on Monday evening is what that week had earned by then. `pets` are
  // the teams added up for it: one, or both for the total. The latest week is in `color`, older ones fainter.
  let {
    weeks,
    labels,
    pets,
    color,
    format,
  }: {
    weeks: WeekdayWeek[]
    labels: string[]
    pets: string[]
    color: string
    format: (value: number) => string
  } = $props()

  const HOURS = 7 * 24
  const HOUR = 3_600_000
  // Any Monday, for the weeks to share: race hours are wall-clock hours of the race's zone, so they're laid on UTC.
  const MONDAY = Date.UTC(2024, 0, 1)
  const END = MONDAY + HOURS * HOUR

  const shade = (i: number) =>
    `color-mix(in oklch, ${color} ${weeks.length > 1 ? 25 + (75 * i) / (weeks.length - 1) : 100}%, var(--muted-foreground))`
  const series = $derived(weeks.map((_, i) => ({ key: `w${i}`, label: labels[i] ?? '', color: shade(i) })))
  // Hour x of each week, or null past where a week has got to, so its line stops there.
  const points = $derived.by(() => {
    const runs = weeks.map((week) => pets.map((pet) => week.xp[pet] ?? []))
    return Array.from({ length: HOURS + 1 }, (_, x) => ({
      at: new Date(MONDAY + x * HOUR).toISOString(),
      ...Object.fromEntries(
        runs.map((teams, i) => [
          `w${i}`,
          x < (teams[0]?.length ?? 0) ? teams.reduce((sum, run) => sum + (run[x] ?? 0), 0) : null,
        ]),
      ),
    }))
  })

  const dayFormatter = new Intl.DateTimeFormat(undefined, { weekday: 'short', timeZone: 'UTC' })
  const hourFormatter = new Intl.DateTimeFormat(undefined, {
    weekday: 'short',
    hour: 'numeric',
    timeZone: 'UTC',
  })
  const hourLabel = (date: Date) =>
    date.getTime() >= END ? 'End of Sunday' : `By ${hourFormatter.format(date)}`
</script>

<TimeSeriesChart
  {points}
  {series}
  kind="line"
  yAxis={false}
  {format}
  xFormat={(date) => (date.getTime() >= END ? '' : dayFormatter.format(date))}
  labelFormat={hourLabel}
  class="h-[280px]"
/>
