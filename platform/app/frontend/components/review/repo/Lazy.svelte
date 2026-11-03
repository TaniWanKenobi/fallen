<script lang="ts" generics="P extends Record<string, unknown>">
  import type { Component } from 'svelte'
  import Spinner from './viewers/Spinner.svelte'

  // A viewer loaded on first use, so its library stays out of the review page's chunk.
  let { load, props }: { load: () => Promise<{ default: Component<P> }>; props: P } = $props()
</script>

{#await load()}
  <Spinner />
{:then mod}
  {@const Viewer = mod.default}
  <Viewer {...props} />
{:catch error}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t load this viewer ({error.message}).</p>
{/await}
