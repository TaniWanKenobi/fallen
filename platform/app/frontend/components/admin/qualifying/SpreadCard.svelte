<script lang="ts">
  import { Deferred } from '@inertiajs/svelte'
  import * as Card from '@/components/admin/ui/card'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import * as ToggleGroup from '@/components/admin/ui/toggle-group'
  import { formatCount } from '@/lib/format'
  import { type Band, COMPARISONS, type Day, dayAgo, daysOf, percent, share, signed } from '@/lib/qualifying'
  import { dayLabel } from '@/lib/streaks'

  // Today's spread around the line (QualifyingPace.spread), band by band, next to the end of the day it's compared
  // with. `comparison` follows the page's range until one is picked here; the page clears it when the range changes.
  let {
    spread,
    timeline,
    today,
    range,
    picked = $bindable(null),
  }: {
    spread: Band[] | undefined
    timeline: Day[] | undefined
    today: string
    range: string
    picked?: string | null
  } = $props()

  const comparison = $derived(picked ?? range)
  const past = $derived(dayAgo(timeline, today, daysOf(comparison)))
  const bands = $derived((spread ?? []).map((band, i) => ({ ...band, before: past?.bands[i] ?? 0 })))
  const below = $derived(bands.filter((band) => band.to !== null && band.to <= 1))
  const above = $derived(bands.filter((band) => band.to === null || band.to > 1))
  const topBand = $derived(Math.max(1, ...bands.flatMap((band) => [band.count, band.before])))
  const sumOf = (list: typeof bands, key: 'count' | 'before') =>
    list.reduce((sum, band) => sum + band[key], 0)
  const pastTotal = $derived(past ? past.bands.reduce((sum, n) => sum + n, 0) : 0)

  const bandLabel = (band: Band) =>
    band.from === null
      ? 'No XP yet'
      : band.to === null
        ? `${share(band.from)}+`
        : band.from === 0
          ? `Under ${share(band.to)}`
          : `${share(band.from)}–${share(band.to)}`
</script>

{#snippet bar(count: number, color: string, faded = false)}
  <div class="flex items-center gap-2">
    <div class="h-4 flex-1 rounded-sm bg-muted">
      <div
        class="h-full rounded-sm transition-[width] duration-500"
        style="width: {(count / topBand) * 100}%; background: {color}; opacity: {faded ? 0.45 : 1}"
      ></div>
    </div>
    <span class="w-10 text-right font-medium tabular-nums">{formatCount(count)}</span>
  </div>
{/snippet}

{#snippet group(title: string, list: typeof bands, color: string)}
  {@const now = sumOf(list, 'count')}
  {@const before = sumOf(list, 'before')}
  <div
    class="mt-3 grid grid-cols-[7.5rem_1fr_1fr_3.5rem] gap-3 border-b pb-1 text-xs font-medium text-muted-foreground first:mt-0"
  >
    <span>{title}</span>
    <span class="tabular-nums">{formatCount(now)} · {percent(now, sumOf(bands, 'count'))}</span>
    <span class="tabular-nums">{formatCount(before)} · {percent(before, pastTotal)}</span>
    <span class="text-right tabular-nums">{signed(now - before)}</span>
  </div>
  {#each list as band (band.from ?? 'none')}
    {@const fill = band.from === null ? 'var(--muted-foreground)' : color}
    <div class="grid grid-cols-[7.5rem_1fr_1fr_3.5rem] items-center gap-3 py-0.5 text-sm">
      <span class="truncate text-muted-foreground">{bandLabel(band)}</span>
      {@render bar(band.count, fill)}
      {@render bar(band.before, fill, true)}
      <span
        class={[
          'text-right text-xs tabular-nums',
          band.count === band.before ? 'text-muted-foreground' : 'font-medium',
        ]}>{signed(band.count - band.before)}</span
      >
    </div>
  {/each}
{/snippet}

<Card.Root class="mt-4">
  <Card.Header class="flex flex-wrap items-start gap-x-4 gap-y-2">
    <div class="flex-1">
      <Card.Title>Above and below the line</Card.Title>
      <Card.Description>
        How far along the line everyone is today, compared with
        {past ? dayLabel(past.date) : 'an earlier day'}
      </Card.Description>
    </div>
    <ToggleGroup.Root
      type="single"
      variant="outline"
      size="sm"
      value={comparison}
      onValueChange={(value) => value && (picked = value)}
    >
      {#each COMPARISONS as option (option.value)}
        <ToggleGroup.Item value={option.value} class="px-2.5 text-xs">{option.label}</ToggleGroup.Item>
      {/each}
    </ToggleGroup.Root>
  </Card.Header>
  <Card.Content>
    <Deferred data={['spread', 'history']}>
      {#snippet fallback()}
        <div class="space-y-2">
          {#each { length: 8 } as _, i (i)}<Skeleton class="h-6 w-full" />{/each}
        </div>
      {/snippet}
      <div class="overflow-x-auto">
        <div class="min-w-[32rem]">
          <div class="grid grid-cols-[7.5rem_1fr_1fr_3.5rem] gap-3 pb-2 text-xs text-muted-foreground">
            <span></span>
            <span>Today</span>
            <span>{past ? dayLabel(past.date) : 'Before'}</span>
            <span class="text-right">Change</span>
          </div>
          {@render group('Below the line', below, 'var(--chart-3)')}
          {@render group('At or above the line', above, 'var(--chart-2)')}
        </div>
      </div>
    </Deferred>
  </Card.Content>
</Card.Root>
