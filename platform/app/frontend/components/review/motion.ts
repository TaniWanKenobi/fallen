import { cubicOut } from 'svelte/easing'
import { fade, fly, slide } from 'svelte/transition'
import { prefersReducedMotion } from '@/components/dialog/motion'

// The review page's transitions, so rows and panels ease in and out rather than snapping, and stay still for people
// who ask for less motion.
const time = (ms: number) => (prefersReducedMotion() ? 0 : ms)

export const reveal = (node: Element) => slide(node, { duration: time(220), easing: cubicOut })
export const appear = (node: Element) => fade(node, { duration: time(160), easing: cubicOut })
export const rise = (node: Element) => fly(node, { y: 6, duration: time(200), easing: cubicOut })
export const pop = (node: Element) => fly(node, { x: -6, duration: time(180), easing: cubicOut })
