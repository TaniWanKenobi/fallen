<script lang="ts">
  import { Button } from '@/components/admin/ui/button'
  import type { RepoSource } from '@/lib/repoFetch'
  import { fileName } from '@/lib/repoFileKinds'
  import { loadLayers, TONE_COLOR, type Layer } from './gerber'
  import Spinner from './Spinner.svelte'

  // A board's layers, each one toggled from the list on the left.
  let { path, source, zip }: { path: string; source: RepoSource; zip: boolean } = $props()

  let layers = $state<Layer[] | null>(null)
  let error = $state<string | null>(null)
  const visible = $derived(layers?.filter((l) => l.visible) ?? [])

  $effect(() => {
    let cancelled = false
    source
      .buffer(path)
      .then((bytes) => loadLayers(bytes, fileName(path), zip))
      .then(
        (l) => !cancelled && (layers = l),
        (e: Error) => !cancelled && (error = e.message),
      )
    return () => (cancelled = true)
  })

  const setAll = (on: boolean) => layers?.forEach((l) => (l.visible = on))
</script>

{#if error}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t render these Gerbers ({error}).</p>
{:else if !layers}
  <Spinner label={zip ? 'Unpacking and plotting layers…' : 'Plotting layer…'} />
{:else}
  <div class="flex h-full min-h-0">
    {#if layers.length > 1}
      <aside class="flex w-56 shrink-0 flex-col gap-1 overflow-y-auto border-r border-border p-2 text-xs">
        <div class="flex gap-1 pb-1">
          <Button variant="ghost" size="xs" onclick={() => setAll(true)}>All</Button>
          <Button variant="ghost" size="xs" onclick={() => setAll(false)}>None</Button>
          <span class="ml-auto self-center text-muted-foreground">{visible.length}/{layers.length}</span>
        </div>
        {#each layers as layer (layer.name)}
          <button
            type="button"
            onclick={() => (layer.visible = !layer.visible)}
            class={[
              'flex items-center gap-2 rounded-md px-2 py-1 text-left hover:bg-muted',
              !layer.visible && 'opacity-40',
            ]}
          >
            <span class="size-2.5 shrink-0 rounded-full" style:background={TONE_COLOR[layer.tone]}></span>
            <span class="min-w-0 flex-1">
              <span class="block truncate font-medium">{layer.label}</span>
              <span class="block truncate text-muted-foreground">{layer.name}</span>
            </span>
          </button>
        {/each}
      </aside>
    {/if}
    <div class="repo-gerber-board relative min-w-0 flex-1 overflow-hidden">
      {#each visible as layer (layer.name)}
        <!-- eslint-disable-next-line svelte/no-at-html-tags -- SVG drawn by tracespace from the parsed geometry -->
        <div class={['absolute inset-0 p-4', layer.tone === 'mask' && 'opacity-60 mix-blend-screen']}>
          {@html layer.svg}
        </div>
      {/each}
      {#if visible.length === 0}
        <p class="absolute inset-0 grid place-items-center text-sm text-zinc-400">No layers selected</p>
      {/if}
    </div>
  </div>
{/if}
