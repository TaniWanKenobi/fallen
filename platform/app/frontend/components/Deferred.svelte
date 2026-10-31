<script lang="ts">
  import { page } from '@inertiajs/svelte'
  import Reveal from '@/components/Reveal.svelte'
  import type { Snippet } from 'svelte'

  // Inertia's <Deferred>, with its content revealed over the fallback by skullet's sweep (Reveal). Same props, for
  // the plain keys this app defers; a prop the server rescued keeps showing the fallback.
  let { data, fallback, children }: { data: string | string[]; fallback: Snippet; children: Snippet } =
    $props()

  const keys = $derived(Array.isArray(data) ? data : [data])
  const loaded = $derived(
    keys.every((key) => page.props[key] !== undefined && !(page.rescuedProps ?? []).includes(key)),
  )
</script>

<Reveal loading={!loaded} skeleton={fallback}>{@render children()}</Reveal>
