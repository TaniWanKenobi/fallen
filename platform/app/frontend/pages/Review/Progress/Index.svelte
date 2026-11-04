<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import Link from '@/components/Link.svelte'
  import type { ColumnDef } from '@tanstack/table-core'
  import Play from '@lucide/svelte/icons/play'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import Morph from '@/components/admin/Morph.svelte'
  import { Button } from '@/components/admin/ui/button'
  import { Input } from '@/components/admin/ui/input'
  import { renderComponent } from '@/components/admin/ui/data-table'
  import Deferred from '@/components/Deferred.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import DueBadge from '@/components/review/progress/DueBadge.svelte'
  import ProjectCell from '@/components/review/progress/ProjectCell.svelte'
  import VerdictBadge from '@/components/review/progress/VerdictBadge.svelte'
  import { formatDate, formatMinutes, timeAgo } from '@/lib/format'
  import { router } from '@inertiajs/svelte'
  import { journalReviewAdd, journalReviewNext, journalReviewProjects, journalReviewRoot } from '@/routes'
  import type { Pagy, ProgressReviewRow, ProgressRow } from '@/types'

  type Counts = {
    queue: number
    by_reason: Record<string, number>
    mine: number
    oldest: string | null
    // Reviews made in the last week, and how long their projects waited on average.
    reviewed_recently: number
    average_wait_seconds: number | null
  }

  // A wait as people say it: "3 hours", "2 days".
  function wait(seconds: number) {
    const hours = seconds / 3600
    if (hours < 1) return `${Math.max(1, Math.round(seconds / 60))} minutes`
    if (hours < 48) return `${Math.round(hours)} ${Math.round(hours) === 1 ? 'hour' : 'hours'}`
    return `${Math.round(hours / 24)} days`
  }

  let {
    projects,
    reviews,
    pagy,
    counts,
    tab,
    reason,
    reasons,
    ladder,
    can_add,
  }: {
    projects?: ProgressRow[]
    reviews?: ProgressReviewRow[]
    pagy?: Pagy
    counts?: Counts
    tab: string
    reason: string | null
    reasons: Record<string, string>
    ladder: { first_at_minutes: number; gaps_minutes: number[] }
    // Admins can put any project in the queue by its link.
    can_add: boolean
  } = $props()

  let link = $state('')
  let adding = $state(false)

  function add(event: SubmitEvent) {
    event.preventDefault()
    adding = true
    router.post(
      journalReviewAdd().url,
      { link: link.trim() },
      { preserveScroll: true, onSuccess: () => (link = ''), onFinish: () => (adding = false) },
    )
  }

  const url = (query: Record<string, string>) =>
    Object.keys(query).length ? journalReviewProjects({ query }).url : journalReviewRoot().url

  const tabs = [
    { value: 'queue', label: 'Queue' },
    { value: 'mine', label: 'My reviews' },
    { value: 'decided', label: 'All reviews' },
  ].map((t) => ({ ...t, href: url(t.value === 'queue' ? {} : { tab: t.value }) }))

  const person = (p: { name: string; avatar: string } | null) =>
    p ? renderComponent(PersonChip, { person: p }) : ''
  const live = (row: ProgressRow) =>
    row.claimed_by && row.claim_expires_at && new Date(row.claim_expires_at) > new Date()

  const projectColumns: ColumnDef<ProgressRow>[] = [
    {
      id: 'project',
      header: 'Project',
      cell: ({ row }) =>
        renderComponent(ProjectCell, {
          id: row.original.id,
          title: row.original.project_title,
          starred: row.original.starred,
          flagged: row.original.flagged,
        }),
    },
    { id: 'owner', header: 'By', cell: ({ row }) => person(row.original.owner) },
    { id: 'logged', header: 'Logged', cell: ({ row }) => formatMinutes(row.original.logged_minutes) },
    {
      id: 'reviews',
      header: 'Reviews',
      cell: ({ row }) =>
        row.original.reviews_count
          ? `${row.original.reviews_count} (${row.original.approvals_count} approved)`
          : 'None yet',
    },
    {
      id: 'why',
      header: 'Why',
      cell: ({ row }) =>
        renderComponent(DueBadge, { reason: row.original.due_reason, label: row.original.due_label }),
    },
    {
      id: 'waiting',
      header: 'Waiting',
      cell: ({ row }) => (row.original.due_since ? timeAgo(row.original.due_since) : ''),
    },
    {
      id: 'claimed',
      header: 'Being reviewed by',
      cell: ({ row }) => (live(row.original) ? person(row.original.claimed_by) : ''),
    },
  ]
  const reviewColumns: ColumnDef<ProgressReviewRow>[] = [
    {
      id: 'project',
      header: 'Project',
      cell: ({ row }) =>
        renderComponent(ProjectCell, { id: row.original.project_id, title: row.original.project_title }),
    },
    { id: 'reviewer', header: 'Reviewer', cell: ({ row }) => person(row.original.reviewer) },
    {
      id: 'verdict',
      header: 'Decision',
      cell: ({ row }) => renderComponent(VerdictBadge, { verdict: row.original.verdict }),
    },
    {
      id: 'why',
      header: 'Came up as',
      cell: ({ row }) =>
        renderComponent(DueBadge, {
          reason: row.original.due_reason,
          label: row.original.due_reason ? reasons[row.original.due_reason] : null,
        }),
    },
    { id: 'logged', header: 'At', cell: ({ row }) => formatMinutes(row.original.logged_minutes) },
    { id: 'when', header: 'When', cell: ({ row }) => formatDate(row.original.created_at) },
  ]

  const badges: Record<string, 'queue' | 'mine'> = { queue: 'queue', mine: 'mine' }
</script>

<svelte:head><title>Journal review · Fallen Admin</title></svelte:head>

<div>
  <div class="mb-6 flex flex-wrap items-end gap-4">
    <div class="min-w-0 flex-1">
      <h1 class="text-2xl font-semibold tracking-tight">Journal review</h1>
      <p class="text-sm text-muted-foreground">
        {#if counts}
          {counts.queue} waiting{#if counts.oldest}, the oldest for {timeAgo(counts.oldest).replace(
              ' ago',
              '',
            )}{/if}.
          {#if counts.reviewed_recently && counts.average_wait_seconds != null}
            Last 7 days: {counts.reviewed_recently} reviewed, after waiting {wait(
              counts.average_wait_seconds,
            )} on average.
          {/if}
        {:else}
          &nbsp;
        {/if}
      </p>
    </div>
    <Button size="lg" href={journalReviewNext().url} class="px-4">
      <Play data-icon="inline-start" /> Start reviewing
    </Button>
  </div>

  {#if can_add}
    <form onsubmit={add} class="mb-5 flex max-w-xl gap-2">
      <Input
        bind:value={link}
        placeholder="Paste a project's link to add it to the front of the queue"
        aria-label="Project link"
        class="flex-1"
      />
      <Button type="submit" variant="outline" disabled={adding || !link.trim()}>Add to queue</Button>
    </form>
  {/if}

  <LinkTabs {tabs} active={tab} class="mb-4">
    {#snippet badge(value)}
      {@const count = badges[value] && counts ? counts[badges[value]] : 0}
      {#if count}
        <span
          class={[
            'rounded-full px-1.5 py-0.5 text-[10px] leading-none font-medium tabular-nums',
            value === 'queue' ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground',
          ]}><Morph text={count} /></span
        >
      {/if}
    {/snippet}
  </LinkTabs>

  {#if tab === 'queue'}
    <div class="mb-4 flex flex-wrap gap-1.5">
      {#each [[null, 'All'], ...Object.entries(reasons)] as [value, label] (value ?? 'all')}
        {@const count = value ? counts?.by_reason[value] : counts?.queue}
        <Link
          href={url(value ? { reason: value } : {})}
          preserveScroll
          class={[
            'rounded-full border px-2.5 py-1 text-xs transition-colors',
            reason === value
              ? 'border-foreground bg-foreground text-background'
              : 'border-border text-muted-foreground hover:text-foreground',
          ]}
        >
          {label}{#if count != null}<span class="ml-1 tabular-nums opacity-70">{count}</span>{/if}
        </Link>
      {/each}
    </div>
  {/if}

  <Deferred data={[tab === 'queue' ? 'projects' : 'reviews', 'pagy']}>
    {#snippet fallback()}
      <DataTableSkeleton headers={['Project', 'By', 'Logged', 'Reviews', 'Why', 'Waiting']} />
    {/snippet}
    {#if reviews}
      <DataTable columns={reviewColumns} data={reviews} {pagy} noun="reviews" />
    {:else}
      <DataTable columns={projectColumns} data={projects ?? []} {pagy} noun="projects" />
    {/if}
  </Deferred>

  <p class="mt-6 text-xs text-muted-foreground">
    A project comes up at {formatMinutes(ladder.first_at_minutes)} logged. Each approval brings it back after
    {ladder.gaps_minutes.map(formatMinutes).join(', then ')} more (the last gap from then on); a check back brings
    it back with their next journal. Once the design is submitted it only comes up if it was never reviewed. <Link
      href={journalReviewNext().url}
      class="underline">Start reviewing</Link
    > claims the next one for you for 15 minutes while the page is open; skipping lets it go.
  </p>
</div>
