<script lang="ts">
  // Adds one removed or deflated stretch, starting at the playhead. Times are video seconds (m:ss on screen).
  import Crosshair from '@lucide/svelte/icons/crosshair'
  import { Button } from '@/components/admin/ui/button'
  import { Input } from '@/components/admin/ui/input'
  import { Label } from '@/components/admin/ui/label'
  import { overlaps, REASONS, timestamp, type Segment, type SegmentType } from '@/lib/lapseReview'

  let {
    type,
    length,
    scale,
    currentTime,
    segments,
    onpreview,
    onadd,
    oncancel,
  }: {
    type: SegmentType
    length: number
    scale: number
    currentTime: number
    segments: Segment[]
    onpreview: (preview: { start: number; end: number; type: SegmentType } | null) => void
    onadd: (segment: Segment) => void
    oncancel: () => void
  } = $props()

  // Starts at the playhead and runs to the next segment edge or the end.
  const [begin, finish] = (() => {
    const from = Math.round(currentTime)
    const edges = [length, ...segments.map((segment) => segment.start)].filter((edge) => edge > from + 1)
    return [from, Math.round(Math.min(...edges, length))]
  })()
  let start = $state(begin)
  let end = $state(finish)
  let reason = $state('')
  // The share of the stretch that still counts.
  let keep = $state(50)

  const clash = $derived(overlaps(segments, start, end))
  const valid = $derived(reason.trim() !== '' && start < end && end <= length + 1 && !clash)
  const minutes = $derived(((end - start) * scale) / 60)

  $effect(() => onpreview(start < end ? { start, end, type } : null))

  function add() {
    if (!valid) return
    onadd({
      type,
      start,
      end,
      reason: reason.trim(),
      ...(type === 'deflated' ? { percent: 100 - keep } : {}),
    })
  }
</script>

<div class="space-y-3 rounded-md border bg-muted/30 p-3">
  <p class="text-sm font-medium">
    {type === 'removed' ? 'Remove' : 'Deflate'} a stretch ({Math.round(minutes)} min of real time)
  </p>
  <div class="grid grid-cols-2 gap-3">
    {#each [['Start', 'start'], ['End', 'end']] as [label, field] (field)}
      <div class="grid gap-1">
        <Label class="text-xs">{label} (video seconds, {timestamp(field === 'start' ? start : end)})</Label>
        <div class="flex gap-1">
          {#if field === 'start'}
            <Input type="number" min={0} max={length} bind:value={start} />
          {:else}
            <Input type="number" min={0} max={length} bind:value={end} />
          {/if}
          <Button
            variant="outline"
            size="icon"
            title="Use the playhead"
            aria-label="Set {label.toLowerCase()} to the playhead"
            onclick={() =>
              field === 'start' ? (start = Math.round(currentTime)) : (end = Math.round(currentTime))}
          >
            <Crosshair />
          </Button>
        </div>
      </div>
    {/each}
  </div>
  <div class="grid gap-1">
    <Label class="text-xs" for="reason-{type}">Reason</Label>
    <Input id="reason-{type}" bind:value={reason} placeholder="Why" list="reasons-{type}" />
    <datalist id="reasons-{type}">
      {#each REASONS[type] as option (option)}<option value={option}></option>{/each}
    </datalist>
    <div class="flex flex-wrap gap-1">
      {#each REASONS[type] as option (option)}
        <button
          type="button"
          class="rounded-full border px-2 py-0.5 text-xs text-muted-foreground hover:text-foreground"
          onclick={() => (reason = option)}>{option}</button
        >
      {/each}
    </div>
  </div>
  {#if type === 'deflated'}
    <div class="grid gap-1">
      <Label class="text-xs" for="keep"
        >Counts ({Math.round((minutes * keep) / 100)} of {Math.round(minutes)} min)</Label
      >
      <div class="flex items-center gap-2">
        <input id="keep" type="range" min={0} max={100} step={5} bind:value={keep} class="flex-1" />
        <span class="w-10 text-right text-sm tabular-nums">{keep}%</span>
      </div>
    </div>
  {/if}
  {#if clash}<p class="text-sm text-destructive">That overlaps a stretch already marked.</p>{/if}
  <div class="flex gap-2">
    <Button size="sm" disabled={!valid} onclick={add}>Add</Button>
    <Button size="sm" variant="ghost" onclick={oncancel}>Cancel</Button>
  </div>
</div>
