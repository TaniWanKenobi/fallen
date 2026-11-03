<script lang="ts">
  import * as pdfjs from 'pdfjs-dist'
  import pdfWorkerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url'
  import { Button } from '@/components/admin/ui/button'
  import type { RepoSource } from '@/lib/repoFetch'
  import { RAISED } from '@/lib/review.svelte'
  import Spinner from './Spinner.svelte'

  pdfjs.GlobalWorkerOptions.workerSrc = pdfWorkerUrl

  // PDFs drawn page by page with pdf.js, ten at a time (Fallout's PdfViewer).
  let { path, source }: { path: string; source: RepoSource } = $props()

  const PAGE_BATCH = 10
  let doc = $state.raw<pdfjs.PDFDocumentProxy | null>(null)
  let error = $state<string | null>(null)
  let shown = $state(PAGE_BATCH)

  $effect(() => {
    let cancelled = false
    let task: pdfjs.PDFDocumentLoadingTask | null = null
    source.buffer(path).then(
      (bytes) => {
        if (cancelled) return
        task = pdfjs.getDocument({ data: new Uint8Array(bytes.slice(0)) })
        task.promise.then(
          (d) => !cancelled && (doc = d),
          (e: Error) => !cancelled && (error = e.message),
        )
      },
      (e: Error) => !cancelled && (error = e.message),
    )
    return () => {
      cancelled = true
      void task?.destroy()
    }
  })

  function page(canvas: HTMLCanvasElement, index: number) {
    let cancelled = false
    let render: pdfjs.RenderTask | null = null
    doc!.getPage(index).then((p) => {
      if (cancelled) return
      const scale = Math.min(2, (window.devicePixelRatio || 1) * 1.25)
      const viewport = p.getViewport({ scale })
      canvas.width = viewport.width
      canvas.height = viewport.height
      canvas.style.width = `${viewport.width / scale}px`
      render = p.render({ canvas, canvasContext: canvas.getContext('2d')!, viewport })
      render.promise.catch(() => {})
    })
    return {
      destroy() {
        cancelled = true
        render?.cancel()
      },
    }
  }
</script>

{#if error}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t open this PDF ({error}).</p>
{:else if !doc}
  <Spinner />
{:else}
  <div class="flex flex-col items-center gap-4 p-4">
    {#each { length: Math.min(doc.numPages, shown) }, i (i)}
      <canvas use:page={i + 1} class="max-w-full rounded-md bg-white shadow-sm"></canvas>
    {/each}
    {#if shown < doc.numPages}
      <Button size="sm" class={RAISED.plain} onclick={() => (shown += PAGE_BATCH)}>
        Show more pages ({doc.numPages - shown} left)
      </Button>
    {/if}
  </div>
{/if}
