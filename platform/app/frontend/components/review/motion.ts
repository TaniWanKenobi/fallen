import { spring } from 'motion'
import type { TransitionConfig } from 'svelte/transition'
import { prefersReducedMotion } from '@/components/dialog/motion'

// The review page's transitions, all on Motion springs (the same feel as the tab bar's pill), and still for people
// who ask for less motion. Svelte runs them, Motion's spring gives the curve.

type Spring = { stiffness: number; damping: number; mass?: number }

// A spring as a duration and an easing Svelte can play, which may go past 1 when the spring overshoots.
function curve(options: Spring) {
  const generator = spring({ keyframes: [0, 1], ...options })
  let duration = 0
  while (duration < 2000 && !generator.next(duration).done) duration += 10
  return { duration, easing: (t: number) => generator.next(t * duration).value }
}

// Rows: settle without overshoot, so a row never grows past its height.
const SETTLE = curve({ stiffness: 380, damping: 39 })
// Small things: a little bounce.
const BOUNCE = curve({ stiffness: 520, damping: 30 })
// Swapping one tab's view for another: quick, and no bounce in the fade.
const QUICK = curve({ stiffness: 1800, damping: 85 })

const still = (): TransitionConfig => ({ duration: 0 })

// A row opening or closing. The height follows the spring while the content fades in behind it and drifts down
// into place, so nothing shows cut off mid-way.
export function reveal(node: Element): TransitionConfig {
  if (prefersReducedMotion()) return still()
  const style = getComputedStyle(node)
  const height = parseFloat(style.height)
  const sides = ['padding-top', 'padding-bottom', 'margin-top', 'margin-bottom'] as const
  const sizes = sides.map((side) => parseFloat(style.getPropertyValue(side)))
  return {
    ...SETTLE,
    css: (t) => {
      const shown = Math.min(Math.max(t, 0), 1)
      return [
        'overflow: hidden',
        `height: ${shown * height}px`,
        ...sides.map((side, i) => `${side}: ${shown * sizes[i]}px`),
        `opacity: ${shown ** 2.5}`,
        `transform: translateY(${(1 - shown) * -6}px)`,
      ].join(';')
    },
  }
}

export function appear(node: Element): TransitionConfig {
  if (prefersReducedMotion()) return still()
  const origin = getComputedStyle(node).transformOrigin
  return {
    ...BOUNCE,
    css: (t) => `opacity: ${Math.min(t, 1)}; transform: scale(${0.9 + 0.1 * t}); transform-origin: ${origin}`,
  }
}

// A tab's view coming in: it fades in where it is, without moving.
export function swap(_node: Element): TransitionConfig {
  if (prefersReducedMotion()) return still()
  return { ...QUICK, css: (t) => `opacity: ${Math.min(t, 1)}` }
}

export function rise(_node: Element): TransitionConfig {
  if (prefersReducedMotion()) return still()
  return { ...BOUNCE, css: (t) => `opacity: ${Math.min(t, 1)}; transform: translateY(${(1 - t) * 8}px)` }
}

export function pop(_node: Element): TransitionConfig {
  if (prefersReducedMotion()) return still()
  return {
    ...BOUNCE,
    css: (t) =>
      `opacity: ${Math.min(t, 1)}; transform: translateX(${(1 - t) * -8}px) scale(${0.94 + 0.06 * t})`,
  }
}
