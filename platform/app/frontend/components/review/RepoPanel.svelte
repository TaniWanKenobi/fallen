<script lang="ts">
  import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right'
  import Check from '@lucide/svelte/icons/check'
  import ChevronRight from '@lucide/svelte/icons/chevron-right'
  import Copy from '@lucide/svelte/icons/copy'
  import Pin from '@lucide/svelte/icons/pin'
  import { Button } from '@/components/admin/ui/button'
  import Key from '@/components/review/Key.svelte'
  import RepoFileViewer from '@/components/review/repo/RepoFileViewer.svelte'
  import Spinner from '@/components/review/repo/viewers/Spinner.svelte'
  import '@/components/review/repo/repo.css'
  import { adminDark } from '@/lib/adminDark.svelte'
  import { createRepoSource } from '@/lib/repoFetch'
  import { fileKind, isReadme, isSignalPath, KIND_LABEL } from '@/lib/repoFileKinds'
  import type { RepoLinks } from '@/lib/repoMarkdown'
  import { RAISED, type ReviewRepo } from '@/lib/review.svelte'
  import { cn } from '@/lib/utils'

  // The repository as it was submitted (RepoSnapshot), after Fallout's RepoWorkspace: a file tree on the left with
  // a Pinned view of the hardware files, the picked file's viewer on the right. Files come through our server from
  // whatever host the repo is on (lib/repoFetch).
  let { repo, submissionId }: { repo: ReviewRepo | null; submissionId: string } = $props()

  const HOSTS: Record<string, string> = {
    'github.com': 'GitHub',
    'gitlab.com': 'GitLab',
    'codeberg.org': 'Codeberg',
    'bitbucket.org': 'Bitbucket',
    'git.sr.ht': 'sourcehut',
  }

  // svelte-ignore state_referenced_locally
  const paths = repo?.paths ?? []
  const pinnedPaths = paths.filter(isSignalPath)
  // svelte-ignore state_referenced_locally
  const source = createRepoSource(submissionId, paths)
  // svelte-ignore state_referenced_locally
  const prefix = repo?.file_url_prefix ?? null
  const fileUrl = (path: string) =>
    prefix ? prefix + path.split('/').map(encodeURIComponent).join('/') : null
  // svelte-ignore state_referenced_locally
  const host = repo ? (HOSTS[repo.host] ?? repo.host) : null
  // svelte-ignore state_referenced_locally
  const links: RepoLinks = { paths: source.paths, dir: '', repoUrl: repo?.url ?? '', fileUrl }

  let pinned = $state(false)
  let selected = $state<string | null>(paths.find((p) => isReadme(p) && !p.includes('/')) ?? null)
  let copied = $state(false)
  let sizeTick = $state(0)
  $effect(() => source.onSize(() => sizeTick++))
  const size = $derived.by(() => {
    void sizeTick
    return selected ? source.size(selected) : null
  })

  export function togglePinned() {
    pinned = !pinned
  }

  function formatFileSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  function copy() {
    if (!selected) return
    void navigator.clipboard.writeText(fileUrl(selected) ?? selected)
    copied = true
    setTimeout(() => (copied = false), 1200)
  }

  // The tree takes keys for its own type-to-search, so the review page's single-key shortcuts pressed while it has
  // focus are handed to the page instead.
  const PAGE_KEYS = new Set(['1', '2', '3', '4', 'n', '?', 'e', 's', 'g', 'p'])
  function forwardShortcut(event: KeyboardEvent) {
    const origin = event.composedPath()[0]
    if (origin instanceof HTMLInputElement || event.ctrlKey || event.metaKey || event.altKey) return
    if (!PAGE_KEYS.has(event.key)) return
    event.stopPropagation()
    window.dispatchEvent(new KeyboardEvent('keydown', { key: event.key, shiftKey: event.shiftKey }))
  }

  function open(path: string) {
    if (pinned && !pinnedPaths.includes(path)) pinned = false
    selected = path
  }
</script>

{#if !repo}
  <p class="p-6 text-sm text-muted-foreground">The repository wasn’t read for this submission.</p>
{:else}
  <div class="flex h-full min-h-0">
    <aside
      class="flex w-72 shrink-0 flex-col border-r border-border bg-muted/40"
      onkeydowncapture={forwardShortcut}
    >
      {#await import('@/components/review/repo/FileTree.svelte')}
        <div class="flex-1"><Spinner /></div>
      {:then { default: FileTree }}
        <FileTree
          {paths}
          {pinnedPaths}
          {pinned}
          {selected}
          dark={adminDark.on}
          onSelect={(path) => (selected = path)}
        />
      {/await}
      <div
        class="flex items-center gap-2 border-t border-border px-2 py-1.5 text-[11px] text-muted-foreground"
      >
        <span class="min-w-0 truncate">
          {pinned ? `${pinnedPaths.length} of ${paths.length}` : paths.length}{repo.truncated ? '+' : ''} files
          · {repo.branch}
        </span>
        <button
          type="button"
          onclick={togglePinned}
          aria-pressed={pinned}
          title="Show only hardware files (README, CAD, PCB, Gerbers, BOM, PDFs)"
          class={cn(
            'ml-auto inline-flex items-center gap-1 rounded-md border px-1.5 py-0.5 font-medium transition-colors',
            pinned
              ? 'border-foreground bg-foreground text-background'
              : 'border-border bg-background hover:bg-accent',
          )}
        >
          <Pin class="size-3" />
          Pinned
          <Key class={cn('ml-0.5', pinned && 'border-background/40 bg-transparent text-background')}>P</Key>
        </button>
      </div>
    </aside>

    <section class="flex min-w-0 flex-1 flex-col">
      <header class="flex h-10 shrink-0 items-center gap-2 border-b border-border px-3 text-xs">
        {#if selected}
          <nav class="flex min-w-0 items-center gap-0.5 text-muted-foreground">
            {#each selected.split('/') as segment, i (i)}
              <span class="flex min-w-0 items-center gap-0.5">
                {#if i > 0}<ChevronRight class="size-3 shrink-0" />{/if}
                <span
                  class={i === selected.split('/').length - 1
                    ? 'truncate font-medium text-foreground'
                    : 'truncate'}>{segment}</span
                >
              </span>
            {/each}
          </nav>
          <span class="ml-auto shrink-0 text-muted-foreground">
            {KIND_LABEL[fileKind(selected)]}{size != null ? ` · ${formatFileSize(size)}` : ''}
          </span>
          <Button
            variant="ghost"
            size="icon-xs"
            title={fileUrl(selected) ? 'Copy link' : 'Copy path'}
            onclick={copy}
          >
            {#if copied}<Check />{:else}<Copy />{/if}
          </Button>
          {#if fileUrl(selected)}
            <Button
              size="xs"
              class={RAISED.plain}
              href={fileUrl(selected)}
              target="_blank"
              rel="noopener noreferrer"
            >
              {host}
              <ArrowUpRight data-icon="inline-end" />
            </Button>
          {/if}
        {:else}
          <span class="truncate text-muted-foreground">
            {repo.url.replace(/^https:\/\//, '')} @
            <span class="font-mono">{repo.commit_sha.slice(0, 7)}</span>
          </span>
        {/if}
      </header>
      <div class="min-h-0 flex-1 overflow-auto bg-background">
        <RepoFileViewer path={selected} {source} dark={adminDark.on} {links} {host} onOpen={open} />
      </div>
    </section>
  </div>
{/if}
