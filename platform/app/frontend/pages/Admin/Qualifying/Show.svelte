<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred } from '@inertiajs/svelte'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import FunnelChart from '@/components/admin/FunnelChart.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import CardTitle from '@/components/admin/qualifying/CardTitle.svelte'
  import OnTrackCard from '@/components/admin/qualifying/OnTrackCard.svelte'
  import SpreadCard from '@/components/admin/qualifying/SpreadCard.svelte'
  import StandingCard from '@/components/admin/qualifying/StandingCard.svelte'
  import SummaryTiles from '@/components/admin/qualifying/SummaryTiles.svelte'
  import * as Card from '@/components/admin/ui/card'
  import { Label } from '@/components/admin/ui/label'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import { Switch } from '@/components/admin/ui/switch'
  import * as ToggleGroup from '@/components/admin/ui/toggle-group'
  import { formatCount } from '@/lib/format'
  import {
    type Band,
    type Day,
    type Group,
    type Lines,
    type Moves,
    RANGES,
    STATUSES,
    type Status,
    dayAgo,
    daysOf,
    onTrack,
    qualifyingColumns,
    signed,
  } from '@/lib/qualifying'
  import { addDays, daysBetween, dayLabel } from '@/lib/streaks'
  import { adminQualifying } from '@/routes'
  import type { AdminQualifyingRow, Pagy } from '@/types'

  type Tab = Status | 'recently_inactive'
  type Summary = {
    // Per status (QualifyingStats.summary): everyone, and those who have journaled.
    statuses: Partial<Record<Status, Record<Group, number>>>
    recently_inactive: number
    hours_to_qualify: { average: number; low: number; high: number } | null
  }

  let {
    tab,
    today,
    deadline,
    goal_xp,
    xp_per_hour,
    off_track_hours,
    close_share,
    lines,
    line_hours,
    quiet_days,
    lock_in,
    summary,
    history,
    spread,
    hours_funnel,
    locking_in,
    rows,
    pagy,
  }: {
    tab: Tab
    today: string
    deadline: string
    goal_xp: number
    xp_per_hour: number
    off_track_hours: number
    close_share: number
    lines: Lines
    // The hours each team's on-track line spends from the race's first day to the deadline.
    line_hours: Record<string, number>
    quiet_days: number
    lock_in: { days: number; hours: number }
    summary?: Summary
    // Each day's counts, and who moved up or slipped over each range (QualifyingPace.history).
    // For everyone, and for each day's builders.
    history?: Record<Group, { days: Day[]; moves: Record<string, Moves> }>
    spread?: Record<Group, Band[]>
    hours_funnel?: { key: string; label: string; count: number }[]
    locking_in?: { count: number; rows: AdminQualifyingRow[] }
    rows?: AdminQualifyingRow[]
    pagy?: Pagy
  } = $props()

  // Counts among builders (people who have written a journal) rather than everyone on a team.
  // On by default: most people on a team never start, so percentages of everyone are all near zero.
  let buildersOnly = $state(true)
  const who: Group = $derived(buildersOnly ? 'builders' : 'all')
  const count = (status: Status) => summary && (summary.statuses[status]?.[who] ?? 0)
  const daysUntil = $derived(Math.max(daysBetween(today, deadline), 0))

  let range = $state('7d')
  // The spread's own comparison, cleared when the range changes so it follows the range again.
  let picked = $state<string | null>(null)

  const timeline = $derived(history?.[who].days)
  const shown = $derived.by(() => {
    const days = daysOf(range)
    if (!timeline || days === null) return timeline ?? []
    return timeline.filter((day) => day.date >= addDays(today, -days))
  })
  const sinceLabel = (days: number | null) =>
    days === null ? 'since the race began' : days === 1 ? 'since yesterday' : `over the last ${days} days`
  // The change in those on track to qualify over the range, end of day to end of day.
  const rangeChange = $derived(
    shown.length < 2
      ? 'Counted at the end of each day'
      : `${signed(onTrack(shown[shown.length - 1]) - onTrack(shown[0]))} ${sinceLabel(daysOf(range))}`,
  )
  const then = $derived(dayAgo(timeline, today, daysOf(range)))
  const moves = $derived(history?.[who].moves[range])
  const movesLabel = $derived(
    moves && then
      ? `${formatCount(moves.up)} moved up and ${formatCount(moves.down)} slipped since ${dayLabel(then.date)}`
      : 'Counted at the end of each day',
  )

  // In QualifyingStats::TABS' order.
  const TAB_LABELS: Record<Tab, string> = {
    on_track: STATUSES.on_track.label,
    recently_inactive: 'Recently inactive',
    behind: STATUSES.behind.label,
    off_track: STATUSES.off_track.label,
    qualified: STATUSES.qualified.label,
    not_started: STATUSES.not_started.label,
  }
  const tabCount = (value: Tab) =>
    value === 'recently_inactive' ? summary?.[value] : summary?.statuses[value]?.all
  const tabs = (Object.keys(TAB_LABELS) as Tab[]).map((value) => ({
    value,
    label: TAB_LABELS[value],
    href: adminQualifying.show({ query: value === 'on_track' ? {} : { tab: value } }).url,
  }))

  const { columns, lockingInColumns, headers } = $derived(
    qualifyingColumns({
      goalXp: goal_xp,
      // Today counts, so someone journaling every day until the deadline has this many.
      daysLeft: Math.max(daysBetween(today, deadline) + 1, 0),
      lockInDays: lock_in.days,
    }),
  )
</script>

<svelte:head><title>Qualifying · Fallen Admin</title></svelte:head>

<div class="mb-5">
  <div class="flex flex-wrap items-center gap-3">
    <h1 class="flex-1 text-2xl font-semibold tracking-tight">Qualifying</h1>
    <div class="flex items-center gap-2">
      <Switch id="builders-only" bind:checked={buildersOnly} />
      <Label for="builders-only" class="text-sm text-muted-foreground">Only people who've journaled</Label>
    </div>
    <ToggleGroup.Root
      type="single"
      variant="outline"
      size="sm"
      value={range}
      onValueChange={(value) => {
        if (!value) return
        range = value
        picked = null
      }}
    >
      {#each RANGES as option (option.value)}
        <ToggleGroup.Item value={option.value} class="px-3 tabular-nums">{option.label}</ToggleGroup.Item>
      {/each}
    </ToggleGroup.Root>
  </div>
  <p class="mt-1 text-sm text-muted-foreground">
    <span class="text-2xl font-semibold text-foreground tabular-nums">{formatCount(daysUntil)}</span>
    {daysUntil === 1 ? 'day' : 'days'} left until {dayLabel(deadline)}
  </p>
</div>

<SummaryTiles
  qualified={count('qualified')}
  on_track={summary && (count('qualified') ?? 0) + (count('on_track') ?? 0)}
  recently_inactive={summary?.recently_inactive}
  hours_to_qualify={summary?.hours_to_qualify}
  {goal_xp}
  {deadline}
  {quiet_days}
  {xp_per_hour}
  {line_hours}
/>

<div class="mt-4 grid gap-4 lg:grid-cols-2">
  <OnTrackCard days={shown} description={rangeChange} {lines} {goal_xp} {deadline} {close_share} />
  <StandingCard days={shown} description={movesLabel} {off_track_hours} />
</div>

<SpreadCard spread={spread?.[who]} {timeline} {today} {range} bind:picked />

<Card.Root class="mt-4">
  <CardTitle
    title="Hours journaled"
    description="Hours people have journaled on Fallen. Each percentage is out of the step before it."
  />
  <Card.Content>
    <Deferred data="hours_funnel">
      {#snippet fallback()}<Skeleton class="h-[320px] w-full" />{/snippet}
      <FunnelChart steps={hours_funnel ?? []} />
    </Deferred>
  </Card.Content>
</Card.Root>

<Card.Root class="mt-4 mb-6">
  <CardTitle
    title="Locking in"
    description="People who journaled {lock_in.hours}h or more in the last {lock_in.days} days, most hours first"
  />
  <Card.Content>
    <Deferred data="locking_in">
      {#snippet fallback()}<DataTableSkeleton headers={['Person', 'Status', ...headers.slice(1)]} />{/snippet}
      <DataTable columns={lockingInColumns} data={locking_in?.rows ?? []} noun="people" />
    </Deferred>
  </Card.Content>
</Card.Root>

<LinkTabs {tabs} active={tab} class="mb-4">
  {#snippet badge(value)}
    {@const n = tabCount(value as Tab)}
    {#if n}
      <span
        class="rounded-full bg-muted px-1.5 py-0.5 text-[10px] leading-none font-medium text-muted-foreground tabular-nums"
        >{formatCount(n)}</span
      >
    {/if}
  {/snippet}
</LinkTabs>

<Deferred data={['rows', 'pagy']}>
  {#snippet fallback()}
    <DataTableSkeleton {headers} />
  {/snippet}
  <DataTable {columns} data={rows ?? []} {pagy} noun="people" />
</Deferred>
