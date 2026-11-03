<script lang="ts">
  import type { Snippet } from 'svelte'
  import ChevronDown from '@lucide/svelte/icons/chevron-down'

  // A card on the review page that remembers whether it was open, per card, in this browser.
  let {
    title,
    storageKey,
    defaultOpen = false,
    summary,
    trailing,
    tone,
    children,
  }: {
    title: string
    storageKey: string
    defaultOpen?: boolean
    summary?: Snippet
    trailing?: Snippet
    tone?: 'warn' | 'fail'
    children: Snippet
  } = $props()

  const key = $derived(`review-card:${storageKey}`)
  // svelte-ignore state_referenced_locally
  let open = $state(
    typeof localStorage !== 'undefined' && localStorage.getItem(`review-card:${storageKey}`) != null
      ? localStorage.getItem(`review-card:${storageKey}`) === '1'
      : defaultOpen,
  )

  function toggle() {
    open = !open
    localStorage.setItem(key, open ? '1' : '0')
  }
</script>

<section
  class={[
    'overflow-hidden rounded-md border',
    tone === 'fail'
      ? 'border-red-300 dark:border-red-900'
      : tone === 'warn'
        ? 'border-amber-300 dark:border-amber-900'
        : 'border-border',
  ]}
>
  <button
    type="button"
    onclick={toggle}
    aria-expanded={open}
    class="flex w-full items-center gap-2 px-3 py-2 text-left hover:bg-muted/50"
  >
    <ChevronDown
      class={['size-4 shrink-0 text-muted-foreground transition-transform', !open && '-rotate-90']}
    />
    <span class="text-sm font-semibold">{title}</span>
    {#if summary}<span class="min-w-0 truncate text-xs text-muted-foreground">{@render summary()}</span>{/if}
    {#if trailing}<span class="ml-auto shrink-0">{@render trailing()}</span>{/if}
  </button>
  {#if open}
    <div class="border-t border-border">{@render children()}</div>
  {/if}
</section>
