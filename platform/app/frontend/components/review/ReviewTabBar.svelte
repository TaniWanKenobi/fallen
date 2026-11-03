<script lang="ts" module>
  import type { Component } from 'svelte'

  export type ReviewTabTint = 'green' | 'blue' | 'amber' | 'violet' | 'gray' | 'red'
  export interface ReviewTab {
    id: string
    title: string
    icon: Component<{ size?: number; strokeWidth?: number; 'aria-hidden'?: 'true' }>
    activeIcon?: Component<{ size?: number; strokeWidth?: number; 'aria-hidden'?: 'true' }>
    tint: ReviewTabTint
  }
</script>

<script lang="ts">
  import '@/components/review/review.css'
  import { animate, motionValue, type AnimationPlaybackControls } from 'motion'
  import { prefersReducedMotion } from '@/components/dialog/motion'

  // Fallout's review tab bar: a raised pill that glides between tabs on a spring and flattens with its speed. The
  // tinted copy of the row shows only inside the pill, so the colour wipes across each label as it passes. The active
  // tab is also a handle: drag it and the pill leans toward the pull, snaps to the nearest tab, and picks it on
  // release.
  let { tabs, value, onChange }: { tabs: ReviewTab[]; value: string; onChange: (id: string) => void } =
    $props()

  const SPRING = { type: 'spring', stiffness: 600, damping: 37, mass: 1 } as const

  let list: HTMLDivElement
  let indicator: HTMLSpanElement
  let layer: HTMLSpanElement
  let visible = $state(false)

  const left = motionValue(0)
  const width = motionValue(0)
  let top = 0
  let height = 0
  let moves: AnimationPlaybackControls[] = []

  function paint() {
    if (!indicator || !layer) return
    const speed = Math.abs(left.getVelocity())
    const squish = prefersReducedMotion() ? 1 : 1 - Math.min(speed / 1100, 1) * 0.18
    Object.assign(indicator.style, {
      left: `${left.get()}px`,
      width: `${width.get()}px`,
      top: `${top}px`,
      height: `${height}px`,
      transform: `scaleY(${squish})`,
    })
    const right = Math.max(0, layer.offsetWidth - left.get() - width.get())
    const bottom = Math.max(0, layer.offsetHeight - top - height)
    layer.style.clipPath = `inset(${top}px ${right}px ${bottom}px ${left.get()}px round 999px)`
  }

  function seat(el: HTMLElement, jump: boolean, lean = 0) {
    top = el.offsetTop
    height = el.offsetHeight
    moves.forEach((m) => m.stop())
    if (jump || prefersReducedMotion()) {
      left.jump(el.offsetLeft + lean)
      width.jump(el.offsetWidth)
      paint()
    } else {
      moves = [animate(left, el.offsetLeft + lean, SPRING), animate(width, el.offsetWidth, SPRING)]
    }
  }

  const tabEls = () => [...list.querySelectorAll<HTMLElement>(':scope > [role="tab"]')]
  const active = () => list?.querySelector<HTMLElement>(':scope > [role="tab"][data-state="active"]')

  $effect(() => {
    void value
    const el = active()
    if (!el) return
    seat(el, !visible)
    visible = true
  })

  $effect(() => {
    const unsubscribe = [left.on('change', paint), width.on('change', paint)]
    const observer = new ResizeObserver(() => {
      const el = active()
      if (el) seat(el, true)
    })
    observer.observe(list)

    // Dragging the active tab. The listeners are on window so letting go outside the bar still ends it.
    let drag: { id: number; x: number; started: boolean; snapped: number; inner: HTMLElement[] } | null = null
    const settle = () => drag?.inner.forEach((el) => (el.style.transform = ''))
    const down = (e: PointerEvent) => {
      const tab = (e.target as HTMLElement).closest<HTMLElement>('[role="tab"]')
      if (e.button !== 0 || !tab || tab.dataset.state !== 'active') return
      drag = { id: e.pointerId, x: e.clientX, started: false, snapped: -1, inner: [] }
    }
    const move = (e: PointerEvent) => {
      if (!drag || e.pointerId !== drag.id) return
      if (!drag.started) {
        if (Math.abs(e.clientX - drag.x) < 5) return
        drag.started = true
        list.dataset.dragging = 'true'
      }
      const x = e.clientX - list.getBoundingClientRect().left + list.scrollLeft
      const els = tabEls()
      const nearest = els.reduce((best, el, i) => {
        const d = Math.abs(el.offsetLeft + el.offsetWidth / 2 - x)
        return d < Math.abs(els[best].offsetLeft + els[best].offsetWidth / 2 - x) ? i : best
      }, 0)
      const el = els[nearest]
      if (drag.snapped !== nearest) {
        settle()
        drag.snapped = nearest
        drag.inner = [el, layer.children[nearest] as HTMLElement]
          .map((t) => t?.querySelector<HTMLElement>('.rc-tab-inner'))
          .filter((t): t is HTMLElement => !!t)
      }
      // The pill stays in its slot but leans toward the pull, with rubber-band resistance up to 18px.
      const lean = Math.tanh((x - (el.offsetLeft + el.offsetWidth / 2)) / (el.offsetWidth * 1.15)) * 18
      seat(el, false, lean)
      if (!prefersReducedMotion())
        drag.inner.forEach((t) => (t.style.transform = `translateX(${lean * 0.5}px)`))
    }
    const up = (e: PointerEvent, commit: boolean) => {
      if (!drag || e.pointerId !== drag.id) return
      settle()
      const { started, snapped } = drag
      drag = null
      delete list.dataset.dragging
      if (!started) return
      if (commit && snapped >= 0) onChange(tabs[snapped].id)
      const el = active()
      if (el) seat(el, false)
    }
    const release = (e: PointerEvent) => up(e, true)
    const cancel = (e: PointerEvent) => up(e, false)
    list.addEventListener('pointerdown', down)
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', release)
    window.addEventListener('pointercancel', cancel)
    return () => {
      unsubscribe.forEach((u) => u())
      observer.disconnect()
      moves.forEach((m) => m.stop())
      list.removeEventListener('pointerdown', down)
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', release)
      window.removeEventListener('pointercancel', cancel)
    }
  })

  function keydown(event: KeyboardEvent) {
    const i = tabs.findIndex((t) => t.id === value)
    const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
    if (!step) return
    event.preventDefault()
    const next = tabs[(i + step + tabs.length) % tabs.length]
    onChange(next.id)
    list.querySelector<HTMLElement>(`[data-tab="${next.id}"]`)?.focus()
  }
</script>

{#snippet inner(tab: ReviewTab, on: boolean)}
  {@const Icon = on && tab.activeIcon ? tab.activeIcon : tab.icon}
  <span class="rc-tab-inner">
    <span class="rc-tab-chip" data-tint={tab.tint}
      ><Icon size={14} strokeWidth={2.5} aria-hidden="true" /></span
    >
    {tab.title}
  </span>
{/snippet}

<div
  bind:this={list}
  class="rc-tabbar"
  role="tablist"
  aria-label="Review views"
  tabindex="-1"
  onkeydown={keydown}
>
  {#each tabs as tab (tab.id)}
    {@const on = tab.id === value}
    <button
      type="button"
      role="tab"
      class="rc-tab"
      data-tab={tab.id}
      data-state={on ? 'active' : 'inactive'}
      aria-selected={on}
      tabindex={on ? 0 : -1}
      onclick={() => onChange(tab.id)}
    >
      {@render inner(tab, on)}
    </button>
  {/each}
  <span bind:this={indicator} class="rc-tab-indicator" style:opacity={visible ? 1 : 0} aria-hidden="true"
  ></span>
  <span bind:this={layer} class="rc-tab-colorlayer" style:opacity={visible ? 1 : 0} aria-hidden="true">
    {#each tabs as tab (tab.id)}
      <span class="rc-tab" data-state={tab.id === value ? 'active' : 'inactive'}
        >{@render inner(tab, tab.id === value)}</span
      >
    {/each}
  </span>
</div>
