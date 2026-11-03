<script lang="ts">
  import type { RepoSource } from '@/lib/repoFetch'
  import { fileName } from '@/lib/repoFileKinds'
  import EasyEdaCanvasView from './EasyEdaCanvasView.svelte'
  import { readEasyEda, type Result } from './easyedaRead'
  import Spinner from './Spinner.svelte'

  // EasyEDA schematics and PCBs drawn as SVG, one sheet at a time (Fallout's EasyEdaViewer).
  let { path, source }: { path: string; source: RepoSource } = $props()

  let result = $state.raw<Result | null>(null)
  let error = $state<string | null>(null)
  let index = $state(0)

  $effect(() => {
    let cancelled = false
    source
      .buffer(path)
      .then((bytes) => readEasyEda(bytes, fileName(path)))
      .then(
        (r) => {
          if (cancelled) return
          if (r.mode === 'sheets') index = r.defaultIndex
          result = r
        },
        (e: Error) => !cancelled && (error = e.message),
      )
    return () => (cancelled = true)
  })

  const sheet = $derived(result?.mode === 'sheets' ? (result.sheets[index] ?? result.sheets[0]) : null)
  const drawing = $derived(sheet ? sheet.build() : null)
</script>

{#if error}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t read this EasyEDA file ({error}).</p>
{:else if !result}
  <Spinner label="Reading EasyEDA project…" />
{:else if result.mode === 'sheets'}
  <div class="flex h-full min-h-0 flex-col">
    {#if result.sheets.length > 1}
      <div class="flex flex-wrap gap-1 border-b border-border p-2">
        {#each result.sheets as s, i (s.id)}
          <button
            type="button"
            onclick={() => (index = i)}
            class={[
              'rounded-md border px-2 py-0.5 text-xs',
              i === index
                ? 'border-foreground bg-foreground text-background'
                : 'border-border hover:bg-muted',
            ]}
          >
            {s.label}
          </button>
        {/each}
      </div>
    {/if}
    {#if drawing}
      <EasyEdaCanvasView document={drawing} />
    {:else}
      <p class="p-6 text-sm text-muted-foreground">
        This sheet uses shapes the renderer doesn’t support yet.
      </p>
    {/if}
  </div>
{:else if result.mode === 'json'}
  {#if result.visual}
    <EasyEdaCanvasView document={result.visual} />
  {:else}
    <div class="p-4 text-xs">
      <p class="mb-2 text-muted-foreground">
        {result.kind === 'unknown'
          ? 'No EasyEDA drawing found in this JSON.'
          : `EasyEDA ${result.kind} without shapes to draw.`}
      </p>
      <pre class="overflow-auto rounded-md bg-muted p-3 font-mono">{result.preview}</pre>
    </div>
  {/if}
{:else}
  {@const entries = result.inspection.entries}
  <div class="p-4 text-xs">
    <p class="mb-2 text-muted-foreground">
      Archive with {entries.length} entries · {entries.filter((e) => e.isEasyEdaJson).length} EasyEDA documents
      found
    </p>
    <ul class="divide-y divide-border rounded-md border border-border">
      {#each entries.slice(0, 140) as e, i (`${e.name}-${i}`)}
        <li class="flex gap-3 px-2 py-1">
          <span class="min-w-0 flex-1 truncate">{e.name}</span>
          <span class="text-muted-foreground">{e.easyEdaDocumentKind ?? (e.isEasyEdaJson ? 'json' : '')}</span
          >
        </li>
      {/each}
    </ul>
  </div>
{/if}
