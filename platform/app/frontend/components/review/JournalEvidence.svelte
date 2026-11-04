<script lang="ts">
  import Markdown from '@/components/Markdown.svelte'
  import { lightboxImages, openLightbox } from '@/components/review/lightbox.svelte'
  import { formatMinutes } from '@/lib/format'
  import type { ReviewJournal } from '@/types'

  // What a journal shows a reviewer: its writing, its photos (opening in the lightbox) and its timelapses.
  let { journal }: { journal: ReviewJournal } = $props()
</script>

<div {@attach lightboxImages}>
  <Markdown source={journal.body} photos={journal.images.map((i) => i.id)} admin />
</div>

{#if journal.images.length}
  <div class="flex flex-wrap gap-1.5">
    {#each journal.images as image, i (image.id)}
      <button
        type="button"
        aria-label="Open {image.filename}"
        onclick={(event) => {
          const thumbs = [...event.currentTarget.parentElement!.querySelectorAll('img')]
          openLightbox(
            journal.images.map((photo, n) => ({ url: photo.url, alt: photo.filename, from: thumbs[n] })),
            i,
          )
        }}
        class="block size-20 cursor-zoom-in overflow-hidden rounded border border-border bg-muted"
      >
        <img
          src={image.url}
          alt={image.filename}
          loading="lazy"
          class="h-full w-full object-cover transition-transform duration-300 hover:scale-105"
        />
      </button>
    {/each}
  </div>
{/if}

{#if journal.timelapses.length}
  <div class="grid grid-cols-2 gap-1.5 sm:grid-cols-3">
    {#each journal.timelapses as t (t.id)}
      <a
        href={t.url}
        target="_blank"
        rel="noopener"
        class="group flex items-center gap-2 rounded border border-border p-1.5 text-xs hover:bg-muted"
      >
        {#if t.thumbnail_url}
          <img
            src={t.thumbnail_url}
            alt=""
            loading="lazy"
            class="h-10 w-16 shrink-0 rounded-sm bg-muted object-cover"
          />
        {/if}
        <span class="min-w-0">
          <span
            class="inline-block rounded bg-purple-100 px-1 text-[10px] font-medium text-purple-700 dark:bg-purple-950 dark:text-purple-300"
            >Lapse</span
          >
          <span class="block truncate">{t.name ?? 'Timelapse'}</span>
          <span class="text-muted-foreground">{formatMinutes(t.duration_minutes)} ↗</span>
        </span>
      </a>
    {/each}
  </div>
{/if}
