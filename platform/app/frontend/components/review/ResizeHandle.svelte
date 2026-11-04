<script lang="ts">
  import { onMount } from 'svelte'

  // The line between a review page's evidence and its decision column, dragged to resize the column on its right.
  // Arrow keys move it too, double-click puts it back, and the width is remembered in this browser under `storageKey`.
  let {
    width = $bindable(),
    min,
    max,
    initial,
    storageKey,
    label = 'Resize the review column',
  }: {
    width: number
    min: number
    max: number
    initial: number
    storageKey: string
    label?: string
  } = $props()

  let dragging = $state(false)
  let startX = 0
  let startWidth = 0

  const clamp = (value: number) =>
    Math.round(Math.min(Math.max(value, min), Math.min(max, window.innerWidth - 320)))

  onMount(() => {
    try {
      const saved = Number(localStorage.getItem(storageKey))
      if (saved) width = clamp(saved)
    } catch {
      // No storage: keep the default.
    }
  })

  function save() {
    try {
      localStorage.setItem(storageKey, String(width))
    } catch {
      // Nothing to keep it in.
    }
  }

  function down(event: PointerEvent) {
    if (event.button !== 0) return
    event.preventDefault()
    ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
    dragging = true
    startX = event.clientX
    startWidth = width
  }

  function move(event: PointerEvent) {
    if (dragging) width = clamp(startWidth - (event.clientX - startX))
  }

  function up() {
    if (!dragging) return
    dragging = false
    save()
  }

  function key(event: KeyboardEvent) {
    const step = event.shiftKey ? 64 : 16
    if (event.key === 'ArrowLeft') width = clamp(width + step)
    else if (event.key === 'ArrowRight') width = clamp(width - step)
    else return
    event.preventDefault()
    save()
  }

  function reset() {
    width = clamp(initial)
    save()
  }
</script>

<svelte:body class:select-none={dragging} class:cursor-col-resize={dragging} />

<!-- svelte-ignore a11y_no_noninteractive_tabindex, a11y_no_noninteractive_element_interactions -->
<div
  role="separator"
  aria-orientation="vertical"
  aria-label={label}
  aria-valuenow={width}
  aria-valuemin={min}
  aria-valuemax={max}
  tabindex="0"
  title="Drag to resize, double-click to reset"
  onpointerdown={down}
  onpointermove={move}
  onpointerup={up}
  onpointercancel={up}
  ondblclick={reset}
  onkeydown={key}
  class="group relative z-20 -mx-1.5 w-3 shrink-0 cursor-col-resize touch-none outline-none"
>
  <span
    class={[
      'absolute inset-y-0 left-1/2 -translate-x-1/2 transition-[width,background-color] duration-150',
      dragging
        ? 'w-0.5 bg-ring'
        : 'w-px bg-border group-hover:w-0.5 group-hover:bg-ring/60 group-focus-visible:w-0.5 group-focus-visible:bg-ring',
    ]}
  ></span>
</div>
