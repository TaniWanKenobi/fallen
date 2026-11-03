<script lang="ts">
  import type { EasyEdaVisualDocument } from './easyeda/easyedaVisual'

  // One EasyEDA sheet as SVG, panned by dragging and zoomed by the wheel or the buttons.
  let { document }: { document: EasyEdaVisualDocument } = $props()

  const FIT_PADDING_SCALE = 1.06
  type ViewBox = { x: number; y: number; width: number; height: number }

  function fitViewBox(doc: EasyEdaVisualDocument): ViewBox {
    const width = Math.max(1, doc.bounds.width * FIT_PADDING_SCALE)
    const height = Math.max(1, doc.bounds.height * FIT_PADDING_SCALE)
    return {
      x: doc.bounds.minX - (width - doc.bounds.width) / 2,
      y: doc.bounds.minY - (height - doc.bounds.height) / 2,
      width,
      height,
    }
  }
  const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value))
  const truncate = (value: string) => (value.length <= 120 ? value : `${value.slice(0, 117)}...`)

  // svelte-ignore state_referenced_locally
  let view = $state<ViewBox>(fitViewBox(document))
  let svg: SVGSVGElement | undefined = $state()
  let pan: { pointerId: number; x: number; y: number; start: ViewBox } | null = $state(null)

  $effect(() => {
    view = fitViewBox(document)
  })

  function zoomBy(scale: number) {
    const s = clamp(scale, 0.2, 5)
    const cx = view.x + view.width / 2
    const cy = view.y + view.height / 2
    const width = clamp(view.width * s, document.bounds.width * 0.01, document.bounds.width * 100)
    const height = (width / view.width) * view.height
    view = { x: cx - width / 2, y: cy - height / 2, width, height }
  }

  $effect(() => {
    if (!svg) return
    const el = svg
    const onWheel = (event: WheelEvent) => {
      event.preventDefault()
      const rect = el.getBoundingClientRect()
      if (rect.width <= 0 || rect.height <= 0) return
      const cursorX = view.x + ((event.clientX - rect.left) / rect.width) * view.width
      const cursorY = view.y + ((event.clientY - rect.top) / rect.height) * view.height
      const width = clamp(
        view.width * (event.deltaY < 0 ? 0.9 : 1.1),
        document.bounds.width * 0.01,
        document.bounds.width * 100,
      )
      const k = width / view.width
      view = {
        x: cursorX - (cursorX - view.x) * k,
        y: cursorY - (cursorY - view.y) * k,
        width,
        height: view.height * k,
      }
    }
    el.addEventListener('wheel', onWheel, { passive: false })
    return () => el.removeEventListener('wheel', onWheel)
  })

  function onpointerdown(event: PointerEvent) {
    if (event.button !== 0 || !svg) return
    svg.setPointerCapture(event.pointerId)
    pan = { pointerId: event.pointerId, x: event.clientX, y: event.clientY, start: view }
  }
  function onpointermove(event: PointerEvent) {
    if (!pan || !svg || pan.pointerId !== event.pointerId) return
    const rect = svg.getBoundingClientRect()
    if (rect.width <= 0 || rect.height <= 0) return
    view = {
      ...pan.start,
      x: pan.start.x - (event.clientX - pan.x) * (pan.start.width / rect.width),
      y: pan.start.y - (event.clientY - pan.y) * (pan.start.height / rect.height),
    }
  }
  function onpointerup(event: PointerEvent) {
    if (pan?.pointerId === event.pointerId) pan = null
  }
  const button = 'rounded-md border border-border bg-background px-2 py-0.5 hover:bg-accent'
</script>

<div class="flex h-full min-h-0 flex-col gap-2 p-3">
  <div class="flex flex-wrap items-center gap-1.5 text-xs">
    <button type="button" class={button} onclick={() => zoomBy(0.85)}>Zoom In</button>
    <button type="button" class={button} onclick={() => zoomBy(1.18)}>Zoom Out</button>
    <button type="button" class={button} onclick={() => (view = fitViewBox(document))}>Fit</button>
    <span class="ml-auto text-muted-foreground"
      >Primitives: <strong>{document.primitives.length}</strong></span
    >
  </div>
  <div class="min-h-0 flex-1 overflow-hidden rounded-md border border-border bg-zinc-950">
    <svg
      bind:this={svg}
      class={['h-full w-full touch-none', pan ? 'cursor-grabbing' : 'cursor-grab']}
      viewBox="{view.x} {view.y} {view.width} {view.height}"
      role="img"
      aria-label="EasyEDA drawing"
      {onpointerdown}
      {onpointermove}
      {onpointerup}
      onpointercancel={onpointerup}
    >
      <rect
        x={document.bounds.minX}
        y={document.bounds.minY}
        width={document.bounds.width}
        height={document.bounds.height}
        fill="#0f1016"
      />
      {#each document.primitives as p, i (i)}
        {#if p.kind === 'polyline'}
          {@const points = p.points.map((pt) => `${pt.x},${pt.y}`).join(' ')}
          {#if p.closed}
            <polygon
              {points}
              stroke={p.stroke}
              stroke-width={p.strokeWidth}
              fill={p.fill ?? 'none'}
              opacity={p.opacity}
              stroke-linejoin="round"
              stroke-linecap="round"
            />
          {:else}
            <polyline
              {points}
              stroke={p.stroke}
              stroke-width={p.strokeWidth}
              fill="none"
              opacity={p.opacity}
              stroke-linejoin="round"
              stroke-linecap="round"
            />
          {/if}
        {:else if p.kind === 'path'}
          <path
            d={p.path}
            stroke={p.stroke}
            stroke-width={p.strokeWidth}
            fill={p.fill ?? 'none'}
            opacity={p.opacity}
            stroke-linejoin="round"
            stroke-linecap="round"
          />
        {:else if p.kind === 'circle'}
          <circle
            cx={p.cx}
            cy={p.cy}
            r={p.r}
            stroke={p.stroke}
            stroke-width={p.strokeWidth}
            fill={p.fill ?? 'none'}
            opacity={p.opacity}
          />
        {:else if p.kind === 'rect'}
          <rect
            x={p.x}
            y={p.y}
            width={p.width}
            height={p.height}
            rx={p.rx}
            ry={p.ry}
            transform={p.rotation !== 0
              ? `rotate(${p.rotation} ${p.x + p.width / 2} ${p.y + p.height / 2})`
              : undefined}
            stroke={p.stroke}
            stroke-width={p.strokeWidth}
            fill={p.fill ?? 'none'}
            opacity={p.opacity}
          />
        {:else}
          <text
            x={p.x}
            y={p.y}
            transform={p.rotation !== 0 ? `rotate(${p.rotation} ${p.x} ${p.y})` : undefined}
            fill="#a0b6e8"
            opacity={p.opacity}
            font-size={p.size}
            text-anchor={p.anchor}
            dominant-baseline="middle"
            style="user-select: none; pointer-events: none">{truncate(p.text)}</text
          >
        {/if}
      {/each}
    </svg>
  </div>
</div>
