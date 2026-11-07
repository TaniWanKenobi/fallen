<script lang="ts">
  import Link from '@/components/Link.svelte'
  import type { ComponentProps } from 'svelte'

  let {
    person,
    href,
    class: className = '',
  }: {
    person: { name: string; avatar: string }
    href?: ComponentProps<typeof Link>['href']
    class?: string
  } = $props()
</script>

{#snippet chip()}
  <img
    src={person.avatar}
    alt=""
    width="16"
    height="16"
    class="size-4 shrink-0 rounded-full bg-muted object-cover"
  />
  <span class={['truncate', href && 'group-hover:underline']}>{person.name}</span>
{/snippet}

{#if href}
  <Link {href} prefetch cacheFor="30s" class="group inline-flex min-w-0 items-center gap-1.5 {className}">
    {@render chip()}
  </Link>
{:else}
  <span class="inline-flex min-w-0 items-center gap-1.5 {className}">{@render chip()}</span>
{/if}
