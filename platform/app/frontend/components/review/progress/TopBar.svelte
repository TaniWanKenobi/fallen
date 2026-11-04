<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Bot from '@lucide/svelte/icons/bot'
  import MessageSquareText from '@lucide/svelte/icons/message-square-text'
  import Moon from '@lucide/svelte/icons/moon'
  import Star from '@lucide/svelte/icons/star'
  import Sun from '@lucide/svelte/icons/sun'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import { Textarea } from '@/components/admin/ui/textarea'
  import Key from '@/components/review/Key.svelte'
  import DueBadge from '@/components/review/progress/DueBadge.svelte'
  import { adminDark, toggleAdminDark } from '@/lib/adminDark.svelte'
  import { formatMinutes } from '@/lib/format'
  import type { ProgressPage } from '@/lib/progressReview'
  import {
    aiFlaggedProjects,
    flagJournalReviewProject,
    journalReviewRoot,
    project,
    releaseJournalReviewProject,
    starJournalReviewProject,
    starredProjects,
    unflagJournalReviewProject,
    unstarJournalReviewProject,
  } from '@/routes'

  let { page }: { page: ProgressPage } = $props()

  let flagReason = $state('')
  let flagging = $state(false)
  let flagOpen = $state(false)

  const skipQuery = $derived(page.skip ? { skip: page.skip } : {})
  const id = $derived(page.project.id)

  export function skip() {
    router.post(releaseJournalReviewProject(id, { query: skipQuery }).url)
  }

  export function toggleStar() {
    if (!page.can.star) return
    const route = page.status.starred ? unstarJournalReviewProject : starJournalReviewProject
    router.post(route(id).url, {}, { preserveScroll: true, preserveState: true })
  }

  export function openFlag() {
    if (page.can.flag) flagOpen = true
  }

  function flag() {
    flagging = true
    router.post(
      flagJournalReviewProject(id, { query: skipQuery }).url,
      { reason: flagReason.trim() },
      { onFinish: () => (flagging = false) },
    )
  }
</script>

<div
  class="relative z-40 flex shrink-0 flex-wrap items-center gap-2 border-b border-border bg-muted/40 px-4 py-3"
>
  <Button variant="outline" href={journalReviewRoot().url}>End session <Key class="ml-1">E</Key></Button>
  {#if page.status.due_since}
    <Button variant="ghost" onclick={skip}>Skip <Key class="ml-1">S</Key></Button>
  {/if}

  <span class="mx-1 hidden h-6 w-px bg-border sm:block"></span>

  <a
    href={project(id).url}
    target="_blank"
    rel="noopener"
    class="max-w-64 truncate font-semibold hover:underline">{page.project.title}</a
  >
  <span class="hidden truncate text-sm text-muted-foreground md:inline">
    by {page.project.team.map((p) => p.name).join(', ')}
  </span>
  <DueBadge reason={page.status.due_reason} label={page.status.due_label} />
  <span class="rounded bg-muted px-1.5 py-0.5 font-mono text-xs"
    >{formatMinutes(page.status.logged_minutes)}</span
  >

  <div class="ml-auto flex flex-wrap items-center gap-2">
    {#if page.project.slack_url}
      <Button variant="outline" href={page.project.slack_url} target="_blank" rel="noopener">
        <MessageSquareText data-icon="inline-start" /> Thread
      </Button>
    {/if}
    <Button variant="ghost" size="icon" aria-label="Toggle dark mode" onclick={toggleAdminDark}>
      {#if adminDark.on}<Sun />{:else}<Moon />{/if}
    </Button>

    <Button
      variant="outline"
      disabled={!page.can.star}
      onclick={toggleStar}
      title={page.status.starred_by ? `Starred by ${page.status.starred_by.name}` : 'Star it as a standout'}
    >
      <Star data-icon="inline-start" class={page.status.starred ? 'fill-amber-400 text-amber-400' : ''} />
      {page.status.starred ? 'Starred' : 'Star'}
      <Key class="ml-1">*</Key>
    </Button>
    {#if page.status.starred}
      <a
        href={starredProjects().url}
        class="text-xs text-muted-foreground hover:text-foreground hover:underline">All starred</a
      >
    {/if}

    {#if page.status.flagged_at}
      <Badge variant="destructive" href={aiFlaggedProjects().url} title={page.status.flag_reason ?? undefined}
        >Flagged for AI</Badge
      >
      {#if page.can.unflag}
        <Button variant="outline" onclick={() => router.post(unflagJournalReviewProject(id).url)}
          >Clear flag</Button
        >
      {/if}
    {:else if page.can.flag}
      <Button variant="destructive" onclick={openFlag}><Bot data-icon="inline-start" /> Flag for AI</Button>
    {/if}
  </div>
</div>

<AlertDialog.Root bind:open={flagOpen}>
  <AlertDialog.Content>
    <AlertDialog.Header>
      <AlertDialog.Title>Flag for AI</AlertDialog.Title>
      <AlertDialog.Description>
        It leaves the queue until an admin looks at it, shows on the AI flags page and is posted in
        #fallen-ai-flags. The team isn’t told.
      </AlertDialog.Description>
    </AlertDialog.Header>
    <Textarea bind:value={flagReason} placeholder="Which journals, and what gave it away?" class="min-h-20" />
    <AlertDialog.Footer>
      <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
      <AlertDialog.Action variant="destructive" disabled={!flagReason.trim() || flagging} onclick={flag}
        >Flag it</AlertDialog.Action
      >
    </AlertDialog.Footer>
  </AlertDialog.Content>
</AlertDialog.Root>
