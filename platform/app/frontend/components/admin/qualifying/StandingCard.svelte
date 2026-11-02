<script lang="ts">
  import { Deferred } from '@inertiajs/svelte'
  import CardTitle from '@/components/admin/qualifying/CardTitle.svelte'
  import TimeSeriesChart from '@/components/admin/TimeSeriesChart.svelte'
  import * as Card from '@/components/admin/ui/card'
  import { Label } from '@/components/admin/ui/label'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import { Switch } from '@/components/admin/ui/switch'
  import { formatCount } from '@/lib/format'
  import { type Day, STATUSES, type Status } from '@/lib/qualifying'

  // How many are in each status day by day over `days`.
  let { days, description, off_track_hours }: { days: Day[]; description: string; off_track_hours: number } =
    $props()

  // Not started dwarfs the rest early on, so it's off the chart unless asked for.
  let showNotStarted = $state(false)
  const series = $derived(
    (['on_track', 'behind', 'off_track', ...(showNotStarted ? ['not_started'] : [])] as Status[]).map(
      (key) => ({
        key,
        label: STATUSES[key].label,
        color: STATUSES[key].color,
      }),
    ),
  )
  // Days are dates in New York; drawn at local midnight so the axis shows the same date.
  const points = $derived(days.map(({ bands: _, ...day }) => ({ ...day, at: `${day.date}T00:00:00` })))
</script>

<Card.Root>
  <CardTitle title="Where everyone stands" {description} {series} />
  <Card.Content>
    <div class="mb-3 flex items-center gap-2">
      <Switch id="show-not-started" bind:checked={showNotStarted} />
      <Label for="show-not-started" class="text-sm text-muted-foreground">Show not started</Label>
      <span class="ml-auto text-xs text-muted-foreground">
        Off track means they'd need {off_track_hours}h+ a day to make it
      </span>
    </div>
    <Deferred data="history">
      {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
      <TimeSeriesChart kind="line" {points} format={(value) => formatCount(Math.round(value))} {series} />
    </Deferred>
  </Card.Content>
</Card.Root>
