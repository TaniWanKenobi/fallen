<script lang="ts">
  import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right'
  import Download from '@lucide/svelte/icons/download'
  import FileIcon from '@lucide/svelte/icons/file'
  import { Button } from '@/components/admin/ui/button'
  import { openLightbox } from '@/components/review/lightbox.svelte'
  import { RAISED } from '@/lib/review.svelte'
  import type { RepoSource } from '@/lib/repoFetch'
  import type { RepoLinks } from '@/lib/repoMarkdown'
  import { fileKind, fileName, KIND_LABEL } from '@/lib/repoFileKinds'
  import Lazy from './Lazy.svelte'
  import MarkdownView from './viewers/MarkdownView.svelte'
  import Spinner from './viewers/Spinner.svelte'

  // One file of the repo, rendered by the viewer for its kind (Fallout's RepoFileViewer). Every heavy viewer is its
  // own chunk, loaded the first time a file of that kind is opened.
  let {
    path,
    source,
    dark,
    links,
    host,
    onOpen,
  }: {
    path: string | null
    source: RepoSource
    dark: boolean
    links: RepoLinks
    host: string | null
    onOpen: (path: string) => void
  } = $props()

  const kind = $derived(path ? fileKind(path) : 'binary')
  const name = $derived(path ? fileName(path) : '')
  const fileUrl = $derived(path ? links.fileUrl(path) : null)
  let downloading = $state(false)

  async function download() {
    if (!path) return
    downloading = true
    try {
      const bytes = await source.buffer(path)
      const url = URL.createObjectURL(new Blob([bytes], { type: 'application/octet-stream' }))
      const a = Object.assign(document.createElement('a'), { href: url, download: name })
      a.click()
      setTimeout(() => URL.revokeObjectURL(url), 10_000)
    } finally {
      downloading = false
    }
  }
</script>

{#snippet fallback(reason?: string)}
  <div class="flex h-full flex-col items-center justify-center gap-3 p-6 text-center">
    <FileIcon class="size-7 text-muted-foreground" />
    <div>
      <p class="font-medium">{name}</p>
      <p class="text-sm text-muted-foreground">
        {reason ?? `No inline preview for ${KIND_LABEL[kind].toLowerCase()} files.`}
      </p>
    </div>
    <div class="flex gap-2">
      {#if fileUrl}
        <Button size="sm" class={RAISED.plain} href={fileUrl} target="_blank" rel="noopener noreferrer">
          View on {host}
          <ArrowUpRight data-icon="inline-end" />
        </Button>
      {/if}
      <Button size="sm" class={RAISED.plain} onclick={download} disabled={downloading}>
        <Download data-icon="inline-start" /> Download
      </Button>
    </div>
  </div>
{/snippet}

{#if !path}
  <div class="flex h-full flex-col items-center justify-center gap-2 text-muted-foreground">
    <FileIcon class="size-6" />
    <p class="text-sm">Pick a file to preview it here</p>
  </div>
{:else}
  {#key path}
    {#if kind === 'markdown'}
      <MarkdownView {path} {source} {links} {onOpen} />
    {:else if kind === 'code'}
      <Lazy load={() => import('./viewers/CodeView.svelte')} props={{ path, source, fallback }} />
    {:else if kind === 'csv'}
      <Lazy load={() => import('./viewers/CsvGrid.svelte')} props={{ path, source, dark, fallback }} />
    {:else if kind === 'image'}
      {#await source.objectUrl(path)}
        <Spinner />
      {:then url}
        <div class="repo-checker flex h-full items-center justify-center p-6">
          <button
            type="button"
            class="max-h-full max-w-full cursor-zoom-in"
            onclick={(event) =>
              openLightbox(
                [{ url, alt: path, from: event.currentTarget.querySelector('img') ?? undefined }],
                0,
              )}
          >
            <img src={url} alt={path} class="max-h-full max-w-full rounded-md object-contain shadow-sm" />
          </button>
        </div>
      {:catch error}
        {@render fallback(`Couldn’t load this file (${error.message}).`)}
      {/await}
    {:else if kind === 'pdf'}
      <Lazy load={() => import('./viewers/PdfViewer.svelte')} props={{ path, source }} />
    {:else if kind === 'model'}
      <Lazy load={() => import('./viewers/ModelViewer.svelte')} props={{ path, source, dark }} />
    {:else if kind === 'step'}
      <Lazy load={() => import('./viewers/StepViewer.svelte')} props={{ path, source, dark }} />
    {:else if kind === 'kicad'}
      <Lazy load={() => import('./viewers/KiCadViewer.svelte')} props={{ path, source, dark }} />
    {:else if kind === 'gerber' || kind === 'gerber_zip'}
      <Lazy
        load={() => import('./viewers/GerberViewer.svelte')}
        props={{ path, source, zip: kind === 'gerber_zip' }}
      />
    {:else if kind === 'easyeda'}
      <Lazy load={() => import('./viewers/EasyEdaViewer.svelte')} props={{ path, source }} />
    {:else}
      {@render fallback()}
    {/if}
  {/key}
{/if}
