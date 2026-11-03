<script lang="ts">
  // Use this instead of Inertia's <Link>. Inertia's never passes a changed href to its click handler when it renders
  // an <a>, so a Link whose href changes in place (filters, pagination, reused rows) visits the URL it started with.
  // Rebuilding it when the href changes fixes that everywhere.
  import { Link as InertiaLink } from '@inertiajs/svelte'
  import type { ComponentProps } from 'svelte'

  let { href, ...rest }: ComponentProps<typeof InertiaLink> = $props()

  const key = $derived(typeof href === 'object' && href ? `${href.method} ${href.url}` : (href ?? ''))
</script>

{#key key}
  <InertiaLink {href} {...rest} />
{/key}
