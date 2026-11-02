<script lang="ts">
  import StatTile from '@/components/admin/StatTile.svelte'
  import { formatCount } from '@/lib/format'
  import { PET_NAMES } from '@/lib/pet.svelte'
  import { dayLabel } from '@/lib/streaks'

  // The few numbers that say who will qualify; each status's count is on its tab and the charts. `qualified` and
  // `on_track` are undefined while the summary loads, as are the rest.
  let {
    qualified,
    on_track,
    recently_inactive,
    hours_to_qualify,
    goal_xp,
    deadline,
    quiet_days,
    xp_per_hour,
    line_hours,
  }: {
    qualified: number | undefined
    on_track: number | undefined
    recently_inactive: number | undefined
    // The total hours everyone on track or qualified will have spent once they have the XP, with their team's reward in
    // full from today (QualifyingStats.hours_to_qualify_sql): the average, and the middle half's range; null with
    // nobody to measure, undefined while loading.
    hours_to_qualify: { average: number; low: number; high: number } | null | undefined
    goal_xp: number
    deadline: string
    quiet_days: number
    xp_per_hour: number
    // The hours each team's on-track line spends from the race's first day to the deadline.
    line_hours: Record<string, number>
  } = $props()

  const lineHours = $derived(
    Object.entries(line_hours)
      .map(([pet, hours]) => `${PET_NAMES[pet] ?? pet} ${formatCount(hours)}h`)
      .join(', '),
  )
  const hoursHint = $derived.by(() => {
    const hours = hours_to_qualify
    const spread =
      hours && hours.low !== hours.high
        ? ` Half need ${formatCount(hours.low)} to ${formatCount(hours.high)}h.`
        : ''
    const about = hours
      ? `Total hours someone on track needs to hit ${formatCount(goal_xp)} XP: what they've logged, plus the rest with their team's rewards (Lulu's weekly bonus, Sami's streak multiplier).${spread}`
      : 'Nobody on track has logged hours yet.'
    return `${about} With no bonuses it's ${formatCount(Math.ceil(goal_xp / xp_per_hour))}h. With every team reward: ${lineHours}.`
  })
</script>

<div class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
  <StatTile
    label="Qualified"
    value={qualified}
    hint="Have {formatCount(goal_xp)} XP and an approved project"
    tone="good"
  />
  <StatTile
    label="On track to qualify"
    value={on_track}
    hint="Qualified, or on pace to hit {formatCount(goal_xp)} XP by {dayLabel(deadline)}"
    tone="good"
  />
  <StatTile
    label="Recently inactive"
    value={recently_inactive}
    hint="On track or close, but no journal in {quiet_days} days"
    tone="bad"
  />
  <StatTile
    label="Average hours to qualify"
    value={hours_to_qualify === undefined
      ? undefined
      : hours_to_qualify
        ? `${formatCount(hours_to_qualify.average)}h`
        : '–'}
    hint={hoursHint}
  />
</div>
