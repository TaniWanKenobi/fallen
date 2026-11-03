<script lang="ts">
  import { Button } from '@/components/admin/ui/button'
  import { renderReadme } from '@/lib/markdown'
  import type { ReviewRepo } from '@/lib/review.svelte'

  // The repository as it was submitted (RepoSnapshot): its files and its README. The hardware files a design needs
  // are pinned, so they're easy to find in a big repo.
  let { repo }: { repo: ReviewRepo | null } = $props()

  const KEY =
    /(readme|bom|bill.?of.?materials)[^/]*$|\.(kicad_pcb|kicad_sch|kicad_pro|brd|sch|pcbdoc|schdoc|epro|fzz|step|stp|f3d|f3z|fcstd|scad|blend|sldprt|ino|uf2|zip|pdf)$|gerber/i
  let filter = $state('')
  let pinned = $state(true)

  const visible = $derived.by(() => {
    if (!repo) return []
    const q = filter.trim().toLowerCase()
    return repo.paths.filter((p) => (q ? p.toLowerCase().includes(q) : !pinned || KEY.test(p))).slice(0, 2000)
  })
  const grouped = $derived.by(() => {
    const groups = new Map<string, string[]>()
    for (const path of visible) {
      const i = path.lastIndexOf('/')
      const dir = i < 0 ? '' : path.slice(0, i)
      groups.set(dir, [...(groups.get(dir) ?? []), path.slice(i + 1)])
    }
    return [...groups.entries()].sort(([a], [b]) => a.localeCompare(b))
  })
  const readme = $derived(repo?.readme ? renderReadme(repo.readme, repo.file_url_prefix) : null)
  const fileUrl = (path: string) =>
    repo?.file_url_prefix ? repo.file_url_prefix + path.split('/').map(encodeURIComponent).join('/') : null
</script>

{#if !repo}
  <p class="p-6 text-sm text-muted-foreground">The repository wasn’t read for this submission.</p>
{:else}
  <div class="grid min-h-full lg:grid-cols-[minmax(260px,340px)_1fr]">
    <aside class="border-b border-border lg:border-r lg:border-b-0">
      <div class="sticky top-0 space-y-2 border-b border-border bg-background/95 p-3 backdrop-blur">
        <a
          href={repo.url}
          target="_blank"
          rel="noopener noreferrer"
          class="block truncate text-sm font-medium hover:underline"
          >{repo.url.replace(/^https:\/\//, '')} ↗</a
        >
        <p class="font-mono text-xs text-muted-foreground">
          {repo.branch} @ {repo.commit_sha.slice(0, 10)} · {repo.paths.length}{repo.truncated ? '+' : ''} files
        </p>
        <div class="flex gap-1.5">
          <input
            bind:value={filter}
            placeholder="Find a file"
            class="h-7 min-w-0 flex-1 rounded-md border border-input bg-background px-2 text-xs"
          />
          <Button
            size="sm"
            variant={pinned && !filter ? 'secondary' : 'ghost'}
            onclick={() => (pinned = !pinned)}
            disabled={!!filter}
          >
            {pinned ? 'Key files' : 'All files'}
          </Button>
        </div>
      </div>
      <div class="max-h-[70vh] overflow-y-auto p-2 font-mono text-xs lg:max-h-none">
        {#each grouped as [dir, files] (dir)}
          <p class="mt-2 px-1 text-muted-foreground first:mt-0">{dir || '/'}</p>
          <ul>
            {#each files as file (file)}
              {@const path = dir ? `${dir}/${file}` : file}
              {@const url = fileUrl(path)}
              <li class={['truncate rounded px-1 py-0.5 pl-3', KEY.test(path) && 'font-semibold']}>
                {#if url}
                  <a href={url} target="_blank" rel="noopener noreferrer" class="hover:underline">{file}</a>
                {:else}
                  {file}
                {/if}
              </li>
            {/each}
          </ul>
        {:else}
          <p class="p-2 text-muted-foreground">
            {filter ? 'No files match.' : 'None of the usual hardware files are here.'}
          </p>
        {/each}
      </div>
    </aside>
    <article class="min-w-0 p-5">
      {#if readme}
        <p class="mb-3 font-mono text-xs text-muted-foreground">{repo.readme_path}</p>
        <!-- eslint-disable-next-line svelte/no-at-html-tags -- sanitised in renderReadme -->
        <div class="prose-review max-w-3xl">{@html readme}</div>
      {:else}
        <p class="text-sm text-muted-foreground">No README.</p>
      {/if}
    </article>
  </div>
{/if}
