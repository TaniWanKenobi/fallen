<script lang="ts">
  // The video's length as a bar: removed stretches red, deflated amber, the one being added dashed. Click or drag to
  // seek; positions snap to segment edges near the pointer.
  import { timestamp, type Segment, type SegmentType } from '@/lib/lapseReview'

  let {
    length,
    segments,
    currentTime,
    preview = null,
    onseek,
  }: {
    length: number
    segments: Segment[]
    currentTime: number
    preview?: { start: number; end: number; type: SegmentType } | null
    onseek: (seconds: number) => void
  } = $props()

  let bar: HTMLDivElement | undefined = $state()
  let dragging = false

  const pct = (seconds: number) => `${Math.min(Math.max((seconds / length) * 100, 0), 100)}%`
  const width = (start: number, end: number) => `${Math.max(((end - start) / length) * 100, 0.5)}%`

  function timeAt(clientX: number) {
    const rect = bar!.getBoundingClientRect()
    const raw = Math.min(Math.max((clientX - rect.left) / rect.width, 0), 1) * length
    const edges = [0, length, ...segments.flatMap((segment) => [segment.start, segment.end])]
    const near = edges.find((edge) => Math.abs(edge - raw) < Math.max(length * 0.015, 1))
    return near ?? Math.round(raw)
  }

  function down(event: PointerEvent) {
    dragging = true
    ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
    onseek(timeAt(event.clientX))
  }
</script>

<div class="space-y-1">
  <div
    bind:this={bar}
    class="relative h-6 cursor-pointer touch-none overflow-hidden rounded-sm bg-muted select-none"
    role="slider"
    tabindex="0"
    aria-label="Position in the video"
    aria-valuemin={0}
    aria-valuemax={Math.round(length)}
    aria-valuenow={Math.round(currentTime)}
    aria-valuetext={timestamp(currentTime)}
    onpointerdown={down}
    onpointermove={(event) => dragging && onseek(timeAt(event.clientX))}
    onpointerup={() => (dragging = false)}
    onkeydown={(event) => {
      if (event.key === 'ArrowRight') onseek(Math.min(currentTime + 5, length))
      if (event.key === 'ArrowLeft') onseek(Math.max(currentTime - 5, 0))
    }}
  >
    {#each segments as segment (segment.start)}
      <div
        class={['absolute inset-y-0', segment.type === 'removed' ? 'bg-red-500/70' : 'bg-amber-500/70']}
        style:left={pct(segment.start)}
        style:width={width(segment.start, segment.end)}
        title="{segment.type} {timestamp(segment.start)}–{timestamp(segment.end)}: {segment.reason}"
      ></div>
    {/each}
    {#if preview && preview.start < preview.end}
      <div
        class={[
          'absolute inset-y-0 border-2 border-dashed',
          preview.type === 'removed'
            ? 'border-red-500/60 bg-red-500/20'
            : 'border-amber-500/60 bg-amber-500/20',
        ]}
        style:left={pct(preview.start)}
        style:width={width(preview.start, preview.end)}
      ></div>
    {/if}
    <div
      class="pointer-events-none absolute inset-y-0 w-0.5 bg-foreground"
      style:left={pct(currentTime)}
    ></div>
  </div>
  <div class="flex justify-between text-[10px] text-muted-foreground tabular-nums">
    <span>{timestamp(currentTime)}</span>
    <span>{timestamp(length)}</span>
  </div>
</div>
