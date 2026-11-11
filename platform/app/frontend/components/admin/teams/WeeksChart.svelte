<script lang="ts">
  import { BarChart } from 'layerchart'
  import { Badge } from '@/components/admin/ui/badge'
  import ChartTooltipRow from '@/components/admin/ChartTooltipRow.svelte'
  import * as Card from '@/components/admin/ui/card'
  import * as Chart from '@/components/admin/ui/chart'
  import * as Table from '@/components/admin/ui/table'
  import * as ToggleGroup from '@/components/admin/ui/toggle-group'
  import Skeleton from '@/components/Skeleton.svelte'
  import WeekdayChart, { type WeekdayWeek } from './WeekdayChart.svelte'
  import { formatCount } from '@/lib/format'

  // Every week of the race side by side: the XP both teams earned in it, or each team's beside the other's. Or, by
  // weekday, every week's running total laid over the others (WeekdayChart).
  let {
    weeks,
    weekdays,
    series,
    byTeam = $bindable(false),
    byWeekday = $bindable(false),
    weekdayTeam = $bindable('total'),
    format = (value: number) => `${formatCount(value)} XP`,
  }: {
    // `running`: the week still going, so its bar is short only because it isn't over.
    weeks: { label: string; dates: string; running: boolean; xp: Record<string, number> }[]
    // Each week's running totals by team, an hour at a time (TeamRace.weekdays); undefined while they load.
    weekdays?: WeekdayWeek[]
    // `short` heads the table's column, so four columns fit a phone.
    series: { key: string; label: string; short: string; color: string }[]
    byTeam?: boolean
    byWeekday?: boolean
    // A pet, or 'total' for both teams.
    weekdayTeam?: string
    format?: (value: number) => string
  } = $props()

  const TOTAL = { key: 'total', label: 'Total XP', color: 'var(--chart-1)' }
  const total = (xp: Record<string, number>) => series.reduce((sum, s) => sum + (xp[s.key] ?? 0), 0)
  const shown = $derived(byTeam ? series : [TOTAL])
  const config = $derived(
    Object.fromEntries(
      [TOTAL, ...series].map((s) => [s.key, { label: s.label, color: s.color }]),
    ) satisfies Chart.ChartConfig,
  )
  const data = $derived(weeks.map((week) => ({ x: week.label, ...week.xp, total: total(week.xp) })))
  const running = $derived(new Set(weeks.filter((week) => week.running).map((week) => week.label)))
  const grand = $derived(weeks.reduce((sum, week) => sum + total(week.xp), 0))
</script>

<Card.Root>
  <Card.Header class="flex flex-row flex-wrap items-start justify-between gap-3">
    <div class="space-y-1.5">
      <Card.Title>{byWeekday ? 'Week against week' : 'Every week'}</Card.Title>
      <Card.Description>
        {byWeekday
          ? 'Each week’s XP so far at each hour from Monday, the latest in full colour'
          : `${format(grand)} earned across ${weeks.length} weeks`}
      </Card.Description>
    </div>
    <div class="flex flex-wrap gap-2">
      <ToggleGroup.Root
        type="single"
        variant="outline"
        size="sm"
        value={byWeekday ? 'weekday' : 'week'}
        onValueChange={(value) => value && (byWeekday = value === 'weekday')}
      >
        <ToggleGroup.Item value="week" class="px-3">Weeks</ToggleGroup.Item>
        <ToggleGroup.Item value="weekday" class="px-3">By weekday</ToggleGroup.Item>
      </ToggleGroup.Root>
      {#if byWeekday}
        <ToggleGroup.Root
          type="single"
          variant="outline"
          size="sm"
          value={weekdayTeam}
          onValueChange={(value) => value && (weekdayTeam = value)}
        >
          <ToggleGroup.Item value="total" class="px-3">Total</ToggleGroup.Item>
          {#each series as s (s.key)}
            <ToggleGroup.Item value={s.key} class="px-3">{s.short}</ToggleGroup.Item>
          {/each}
        </ToggleGroup.Root>
      {:else}
        <ToggleGroup.Root
          type="single"
          variant="outline"
          size="sm"
          value={byTeam ? 'team' : 'total'}
          onValueChange={(value) => value && (byTeam = value === 'team')}
        >
          <ToggleGroup.Item value="total" class="px-3">Total</ToggleGroup.Item>
          <ToggleGroup.Item value="team" class="px-3">By team</ToggleGroup.Item>
        </ToggleGroup.Root>
      {/if}
    </div>
  </Card.Header>
  <Card.Content class="space-y-4">
    {#if !byWeekday}
      <Chart.Container {config} class="aspect-auto h-[280px] w-full">
        <BarChart
          {data}
          x="x"
          series={shown}
          seriesLayout={byTeam ? 'group' : 'overlap'}
          padding={{ top: 4, left: 56, right: 4, bottom: 20 }}
          props={{
            yAxis: { format: (value: number) => formatCount(value), ticks: 4 },
            bars: { radius: 4, strokeWidth: 0 },
          }}
        >
          {#snippet tooltip()}
            <Chart.Tooltip
              indicator="dot"
              labelFormatter={(x: string) => `${x}${running.has(x) ? ' (so far)' : ''}`}
            >
              {#snippet formatter({ value, name, item })}
                <ChartTooltipRow {name} color={item.color} {value} {format} />
              {/snippet}
            </Chart.Tooltip>
          {/snippet}
        </BarChart>
      </Chart.Container>
    {:else if weekdays}
      <WeekdayChart
        weeks={weekdays}
        labels={weeks.map((week) => week.label)}
        pets={weekdayTeam === 'total' ? series.map((s) => s.key) : [weekdayTeam]}
        color={series.find((s) => s.key === weekdayTeam)?.color ?? TOTAL.color}
        {format}
      />
    {:else}
      <Skeleton class="h-[280px] w-full rounded-md" />
    {/if}

    <Table.Root>
      <Table.Header>
        <Table.Row>
          <Table.Head>Week</Table.Head>
          {#each series as s (s.key)}<Table.Head class="text-right">{s.short}</Table.Head>{/each}
          <Table.Head class="text-right">Total</Table.Head>
        </Table.Row>
      </Table.Header>
      <Table.Body>
        {#each weeks as week (week.label)}
          <Table.Row>
            <Table.Cell>
              <span class="font-medium">{week.label}</span>
              {#if week.running}<Badge variant="outline" class="ml-1 text-[10px]">so far</Badge>{/if}
              <span class="ml-2 hidden text-xs text-muted-foreground sm:inline">{week.dates}</span>
            </Table.Cell>
            {#each series as s (s.key)}
              <Table.Cell class="text-right tabular-nums">{formatCount(week.xp[s.key] ?? 0)}</Table.Cell>
            {/each}
            <Table.Cell class="text-right font-medium tabular-nums">{formatCount(total(week.xp))}</Table.Cell>
          </Table.Row>
        {/each}
      </Table.Body>
    </Table.Root>
  </Card.Content>
</Card.Root>
