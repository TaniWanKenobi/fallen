<script lang="ts">
  import { Deferred } from '@inertiajs/svelte'
  import CardTitle from '@/components/admin/qualifying/CardTitle.svelte'
  import TimeSeriesChart from '@/components/admin/TimeSeriesChart.svelte'
  import * as Card from '@/components/admin/ui/card'
  import { Label } from '@/components/admin/ui/label'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import { Switch } from '@/components/admin/ui/switch'
  import { formatCount } from '@/lib/format'
  import { PET_NAMES } from '@/lib/pet.svelte'
  import { type Day, type Lines, STATUSES, onTrack, share } from '@/lib/qualifying'
  import { dayLabel } from '@/lib/streaks'

  // Those on track to qualify day by day over `days`, with what each line means in XP today.
  let {
    days,
    description,
    lines,
    goal_xp,
    deadline,
    close_share,
  }: {
    days: Day[]
    description: string
    lines: Lines
    goal_xp: number
    deadline: string
    close_share: number
  } = $props()

  // Whether the Qualified line needs an approved project, as qualifying does, or only the XP. On track or qualified is
  // the same either way: anyone with the XP and no approved project is on track.
  // Off by default while no project has been approved yet, so the line shows who has the XP.
  let needsProject = $state(false)

  // Days are dates in New York; drawn at local midnight so the axis shows the same date.
  const points = $derived(
    days.map((day) => ({
      at: `${day.date}T00:00:00`,
      projected: onTrack(day),
      qualified: needsProject ? day.qualified : day.reached,
      close: day.close,
    })),
  )
  const series = [
    { key: 'projected', label: 'On track or qualified', color: 'var(--chart-1)' },
    { key: 'qualified', label: 'Qualified', color: STATUSES.qualified.color },
    { key: 'close', label: 'Just below the line', color: STATUSES.behind.color },
  ]

  // What each line means in XP today; the line differs by team, as each team's reward does.
  const byTeam = (range: (line: { on_track: number; close: number }) => string) =>
    Object.entries(lines)
      .map(([pet, line]) => `${PET_NAMES[pet] ?? pet} ${range(line)}`)
      .join(' · ')
  const legend = $derived([
    {
      ...series[0],
      xp: `${byTeam((line) => `${formatCount(line.on_track)}+`)} XP, or qualified`,
      means: `At or above the line, the steady pace that hits ${formatCount(goal_xp)} XP by ${dayLabel(deadline)}`,
    },
    {
      ...series[1],
      xp: `${formatCount(goal_xp)}+ XP${needsProject ? ' and an approved project' : ', approved project or not'}`,
      means: needsProject
        ? 'Done. They move on to the final stage'
        : 'Have the XP. Some still need a project approved',
    },
    {
      ...series[2],
      xp: `${byTeam((line) => `${formatCount(line.close)}–${formatCount(Math.max(line.on_track - 1, line.close))}`)} XP`,
      means: `Between ${share(close_share)} and 100% of the line. A few good days would get them on track`,
    },
  ])
</script>

<Card.Root>
  <CardTitle title="On track to qualify" {description} {series} />
  <Card.Content>
    <div class="mb-3 flex items-center gap-2">
      <Switch id="needs-project" bind:checked={needsProject} />
      <Label for="needs-project" class="text-sm text-muted-foreground"
        >Only count approved projects as qualified</Label
      >
    </div>
    <Deferred data="history">
      {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
      <TimeSeriesChart {points} format={(value) => formatCount(Math.round(value))} {series} />
    </Deferred>
    <dl class="mt-4 space-y-2 border-t pt-3 text-xs">
      {#each legend as item (item.key)}
        <div class="grid grid-cols-[auto_1fr] gap-x-2">
          <span class="mt-1 size-2 rounded-[2px]" style="background: {item.color}"></span>
          <div>
            <dt class="font-medium">
              {item.label} <span class="font-normal text-muted-foreground tabular-nums">· {item.xp}</span>
            </dt>
            <dd class="text-muted-foreground">{item.means}</dd>
          </div>
        </div>
      {/each}
    </dl>
  </Card.Content>
</Card.Root>
