<script lang="ts" generics="T extends string">
  import '@/components/review/review.css'
  import { animate, type AnimationPlaybackControls } from 'motion'
  import { prefersReducedMotion } from '@/components/dialog/motion'
  import type { ReviewTabTint } from '@/components/review/ReviewTabBar.svelte'
  import Morph from '@/components/admin/Morph.svelte'

  // A small choice in the review tab bar's look: a muted track with a raised pill that springs to the picked option,
  // whose label fades to its tint. Used for every call on the review page (rubric answers, journal time, parts).
  let {
    options,
    value,
    onChange,
    label,
    disabled = false,
    size = 'sm',
  }: {
    options: { value: T; label: string; count?: number; tint: ReviewTabTint; title?: string }[]
    value: T | null | undefined
    onChange: (value: T) => void
    label: string
    disabled?: boolean
    size?: 'sm' | 'xs'
  } = $props()

  const SPRING = { type: 'spring', stiffness: 600, damping: 38 } as const

  let track: HTMLDivElement
  let pill: HTMLSpanElement
  let shown = false
  let move: AnimationPlaybackControls | undefined

  // Follows the picked option, and its size when labels change. The first placement and reduced motion don't animate.
  $effect(() => {
    const index = options.findIndex((o) => o.value === value)
    void options.map((o) => o.label).join()
    const target = index < 0 ? null : (track.children[index] as HTMLElement | undefined)
    move?.stop()
    if (!target) {
      move = animate(pill, { opacity: 0, scale: 0.9 }, { duration: prefersReducedMotion() ? 0 : 0.15 })
      shown = false
      return
    }
    const box = {
      left: `${track.offsetLeft + target.offsetLeft}px`,
      width: `${target.offsetWidth}px`,
      opacity: 1,
      scale: 1,
    }
    if (!shown || prefersReducedMotion()) {
      Object.assign(pill.style, { left: box.left, width: box.width })
      move = animate(pill, { opacity: 1, scale: 1 }, { duration: prefersReducedMotion() ? 0 : 0.18 })
      shown = true
    } else {
      move = animate(pill, box, SPRING)
    }
  })
</script>

<div class="seg" role="radiogroup" aria-label={label} data-size={size}>
  <div bind:this={track} class="seg-track">
    {#each options as option (option.value)}
      {@const on = option.value === value}
      <button
        type="button"
        role="radio"
        aria-checked={on}
        {disabled}
        title={option.title}
        data-tint={option.tint}
        class="seg-item"
        onclick={() => onChange(option.value)}
        >{option.label}{#if option.count != null}&nbsp;<span class="seg-count"
            >(<Morph text={option.count} />)</span
          >{/if}</button
      >
    {/each}
  </div>
  <span bind:this={pill} class="seg-pill" aria-hidden="true"></span>
</div>

<style>
  .seg {
    position: relative;
    display: inline-flex;
    flex: none;
    padding: 0.18rem;
    border-radius: 999px;
    background: var(--muted);
  }
  .seg-track {
    position: relative;
    z-index: 1;
    display: inline-flex;
    align-items: center;
    gap: 0.1rem;
  }
  .seg-pill {
    position: absolute;
    top: 0.18rem;
    bottom: 0.18rem;
    left: 0;
    width: 0;
    z-index: 0;
    border-radius: 999px;
    background: var(--card);
    box-shadow: var(--rc-shadow-raise);
    opacity: 0;
    pointer-events: none;
  }
  .seg-item {
    border-radius: 999px;
    padding: 0.2rem 0.65rem;
    font-size: 0.75rem;
    font-weight: 600;
    white-space: nowrap;
    color: color-mix(in oklch, var(--foreground) 50%, transparent);
    transition: color 200ms ease-out;
  }
  .seg[data-size='xs'] .seg-item {
    padding: 0.12rem 0.5rem;
    font-size: 0.7rem;
  }
  .seg-item:hover:not(:disabled):not([aria-checked='true']) {
    color: color-mix(in oklch, var(--foreground) 80%, transparent);
  }
  .seg-count {
    font-variant-numeric: tabular-nums;
  }
  .seg-item:disabled {
    cursor: default;
  }
  .seg-item:focus-visible {
    outline: 2px solid var(--ring);
    outline-offset: 1px;
  }
  .seg-item[aria-checked='true'] {
    color: var(--foreground);
  }
  .seg-item[aria-checked='true'][data-tint='green'] {
    color: var(--rc-chip-green-ink);
  }
  .seg-item[aria-checked='true'][data-tint='amber'] {
    color: var(--rc-chip-amber-ink);
  }
  .seg-item[aria-checked='true'][data-tint='blue'] {
    color: var(--rc-chip-blue-ink);
  }
  .seg-item[aria-checked='true'][data-tint='violet'] {
    color: var(--rc-chip-violet-ink);
  }
  .seg-item[aria-checked='true'][data-tint='red'] {
    color: var(--rc-chip-red-ink);
  }
  .seg-item[aria-checked='true'][data-tint='gray'] {
    color: var(--rc-chip-gray-ink);
  }
</style>
