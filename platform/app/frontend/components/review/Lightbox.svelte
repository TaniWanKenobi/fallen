<script lang="ts">
  import { animate } from 'motion'
  import ChevronLeft from '@lucide/svelte/icons/chevron-left'
  import ChevronRight from '@lucide/svelte/icons/chevron-right'
  import ExternalLink from '@lucide/svelte/icons/external-link'
  import X from '@lucide/svelte/icons/x'
  import Morph from '@/components/admin/Morph.svelte'
  import { prefersReducedMotion } from '@/components/dialog/motion'
  import { closeLightbox, lightbox } from '@/components/review/lightbox.svelte'

  // The review page's lightbox. A picture grows out of the thumbnail it was opened from and shrinks back into it on
  // close, all on springs; arrows (or the keys) page through the rest. While it's open it has the keyboard, so the
  // page's own shortcuts don't fire behind it.
  const SPRING = { type: 'spring', stiffness: 380, damping: 34 } as const
  const SWITCH = { type: 'spring', stiffness: 520, damping: 40 } as const

  let image: HTMLImageElement | undefined = $state()
  let backdrop: HTMLDivElement | undefined = $state()
  let closing = false
  let shownIndex = -1

  const open = $derived(lightbox.index >= 0 && lightbox.images.length > 0)
  const current = $derived(open ? lightbox.images[lightbox.index] : undefined)
  const many = $derived(lightbox.images.length > 1)

  // Where the picture would sit if it were the thumbnail: the shift and scale that take its full-size box there.
  function towards(from: HTMLElement | undefined) {
    if (!image || !from?.isConnected) return null
    const end = image.getBoundingClientRect()
    const start = from.getBoundingClientRect()
    if (!start.width || !end.width) return null
    return {
      x: start.left + start.width / 2 - (end.left + end.width / 2),
      y: start.top + start.height / 2 - (end.top + end.height / 2),
      scale: Math.max(start.width / end.width, start.height / end.height),
    }
  }

  async function show(index: number, first: boolean) {
    const target = image
    if (!target) return
    await target.decode().catch(() => {})
    if (target !== image || lightbox.index !== index) return
    const still = prefersReducedMotion()
    if (first) {
      if (backdrop) animate(backdrop, { opacity: [0, 1] }, still ? { duration: 0 } : { duration: 0.2 })
      const from = towards(current?.from)
      if (from && !still) {
        animate(target, { x: [from.x, 0], y: [from.y, 0], scale: [from.scale, 1], opacity: [0.6, 1] }, SPRING)
      } else {
        animate(target, { opacity: [0, 1], scale: [0.96, 1] }, still ? { duration: 0 } : SPRING)
      }
    } else {
      animate(target, { opacity: [0, 1], scale: [0.97, 1] }, still ? { duration: 0 } : SWITCH)
    }
  }

  $effect(() => {
    const index = lightbox.index
    if (!open || !image) {
      shownIndex = -1
      return
    }
    if (index === shownIndex) return
    const first = shownIndex < 0
    shownIndex = index
    closing = false
    void show(index, first)
  })

  async function close() {
    if (closing || !open) return
    closing = true
    const still = prefersReducedMotion()
    const to = towards(current?.from)
    const moves = [
      backdrop && animate(backdrop, { opacity: 0 }, still ? { duration: 0 } : { duration: 0.2 }),
      image &&
        (to && !still
          ? animate(image, { x: to.x, y: to.y, scale: to.scale, opacity: 0.3 }, SPRING)
          : animate(image, { opacity: 0, scale: 0.96 }, still ? { duration: 0 } : { duration: 0.15 })),
    ]
    await Promise.all(moves.filter(Boolean).map((m) => m!.finished))
    closeLightbox()
  }

  function go(step: number) {
    if (!many || closing) return
    lightbox.index = (lightbox.index + step + lightbox.images.length) % lightbox.images.length
  }

  function keydown(event: KeyboardEvent) {
    if (!open) return
    event.stopImmediatePropagation()
    if (event.key === 'Escape') {
      event.preventDefault()
      void close()
    } else if (event.key === 'ArrowLeft') {
      event.preventDefault()
      go(-1)
    } else if (event.key === 'ArrowRight') {
      event.preventDefault()
      go(1)
    }
  }

  $effect(() => {
    if (!open) return
    window.addEventListener('keydown', keydown, { capture: true })
    return () => window.removeEventListener('keydown', keydown, { capture: true })
  })
</script>

{#if open && current}
  <div
    class="fixed inset-0 z-[100] flex items-center justify-center"
    role="dialog"
    aria-modal="true"
    aria-label="Image viewer"
  >
    <div
      bind:this={backdrop}
      class="absolute inset-0 bg-black/85 backdrop-blur-sm"
      role="presentation"
      onclick={close}
    ></div>

    <img
      bind:this={image}
      src={current.url}
      alt={current.alt}
      class="relative max-h-[86vh] max-w-[90vw] rounded-lg object-contain shadow-2xl will-change-transform"
      style="opacity: 0"
    />

    <div
      class="pointer-events-none absolute inset-x-0 top-0 flex items-center justify-between p-4 text-sm text-white/80"
    >
      <span class="font-mono tabular-nums">
        {#if many}<Morph text={lightbox.index + 1} /> / {lightbox.images.length}{/if}
      </span>
      <div class="pointer-events-auto flex items-center gap-1">
        <a
          href={current.url}
          target="_blank"
          rel="noopener"
          class="flex items-center gap-1.5 rounded-full px-3 py-1.5 text-white/80 transition-colors hover:bg-white/10 hover:text-white"
        >
          Original <ExternalLink class="size-3.5" />
        </a>
        <button
          type="button"
          onclick={close}
          aria-label="Close"
          class="grid size-9 place-items-center rounded-full text-white/80 transition-colors hover:bg-white/10 hover:text-white"
        >
          <X class="size-5" />
        </button>
      </div>
    </div>

    {#if many}
      <button
        type="button"
        onclick={() => go(-1)}
        aria-label="Previous image"
        class="absolute left-4 grid size-11 place-items-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20"
      >
        <ChevronLeft class="size-6" />
      </button>
      <button
        type="button"
        onclick={() => go(1)}
        aria-label="Next image"
        class="absolute right-4 grid size-11 place-items-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20"
      >
        <ChevronRight class="size-6" />
      </button>
    {/if}

    {#if current.alt}
      <p class="pointer-events-none absolute inset-x-0 bottom-0 p-4 text-center text-sm text-white/70">
        {current.alt}
      </p>
    {/if}
  </div>
{/if}
