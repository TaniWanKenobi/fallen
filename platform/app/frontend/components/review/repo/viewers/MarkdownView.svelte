<script lang="ts">
  import { lightboxImages } from '@/components/review/lightbox.svelte'
  import type { RepoSource } from '@/lib/repoFetch'
  import { renderRepoMarkdown, type RepoLinks } from '@/lib/repoMarkdown'
  import { MAX_TEXT_BYTES } from '@/lib/repoFileKinds'
  import Spinner from './Spinner.svelte'

  // A Markdown file of the repo, sanitised (renderRepoMarkdown). Its pictures that are files of the repo come
  // through our file endpoint; links to other files of the repo open them here.
  let {
    path,
    source,
    links,
    onOpen,
  }: { path: string; source: RepoSource; links: RepoLinks; onOpen: (path: string) => void } = $props()

  let article: HTMLElement | undefined = $state()

  async function load() {
    const bytes = await source.buffer(path)
    if (bytes.byteLength > MAX_TEXT_BYTES) throw new Error('it is too large to preview inline')
    const dir = path.includes('/') ? path.slice(0, path.lastIndexOf('/') + 1) : ''
    return renderRepoMarkdown(new TextDecoder().decode(bytes), { ...links, dir })
  }

  $effect(() => {
    if (!article) return
    for (const img of article.querySelectorAll<HTMLImageElement>('img[data-repo-src]')) {
      source.objectUrl(img.dataset.repoSrc!).then(
        (url) => (img.src = url),
        () => img.replaceWith(`[image: ${img.alt || img.dataset.repoSrc}]`),
      )
    }
  })

  function onclick(event: MouseEvent) {
    const link = (event.target as HTMLElement).closest<HTMLAnchorElement>('a[data-repo-path]')
    if (!link || event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return
    event.preventDefault()
    onOpen(link.dataset.repoPath!)
  }
</script>

{#await load()}
  <Spinner />
{:then html}
  <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
  <article bind:this={article} class="repo-markdown" {onclick} {@attach lightboxImages}>
    <!-- eslint-disable-next-line svelte/no-at-html-tags -- sanitised in renderRepoMarkdown -->
    {@html html}
  </article>
{:catch error}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t load this file ({error.message}).</p>
{/await}
