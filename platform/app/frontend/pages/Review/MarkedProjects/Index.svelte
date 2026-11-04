<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import type { ColumnDef } from '@tanstack/table-core'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import { renderComponent } from '@/components/admin/ui/data-table'
  import Deferred from '@/components/Deferred.svelte'
  import Link from '@/components/Link.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import DueBadge from '@/components/review/progress/DueBadge.svelte'
  import ProjectCell from '@/components/review/progress/ProjectCell.svelte'
  import { formatMinutes, timeAgo } from '@/lib/format'
  import { journalReviewRoot } from '@/routes'
  import type { Pagy, ProgressRow } from '@/types'

  // Projects journal reviewers marked, on their own page: starred as standouts, or flagged as written by AI. Both
  // are on the project, not a journal; each row opens the project's journal review.
  let { projects, pagy, kind }: { projects?: ProgressRow[]; pagy?: Pagy; kind: 'starred' | 'flagged' } =
    $props()

  const starred = $derived(kind === 'starred')
  const person = (p: { name: string; avatar: string } | null) =>
    p ? renderComponent(PersonChip, { person: p }) : ''

  const columns: ColumnDef<ProgressRow>[] = $derived([
    {
      id: 'project',
      header: 'Project',
      cell: ({ row }) =>
        renderComponent(ProjectCell, {
          id: row.original.id,
          title: row.original.project_title,
          starred: !starred && row.original.starred,
          flagged: starred && row.original.flagged,
        }),
    },
    { id: 'owner', header: 'By', cell: ({ row }) => person(row.original.owner) },
    { id: 'logged', header: 'Logged', cell: ({ row }) => formatMinutes(row.original.logged_minutes) },
    ...(starred
      ? [
          {
            id: 'by',
            header: 'Starred by',
            cell: ({ row }) => person(row.original.starred_by),
          } satisfies ColumnDef<ProgressRow>,
        ]
      : [
          {
            id: 'by',
            header: 'Flagged by',
            cell: ({ row }) => person(row.original.flagged_by),
          } satisfies ColumnDef<ProgressRow>,
          {
            id: 'why',
            header: 'Why',
            cell: ({ row }) => row.original.flag_reason ?? '',
          } satisfies ColumnDef<ProgressRow>,
        ]),
    {
      id: 'when',
      header: starred ? 'Starred' : 'Flagged',
      cell: ({ row }) => {
        const at = starred ? row.original.starred_at : row.original.flagged_at
        return at ? timeAgo(at) : ''
      },
    },
    {
      id: 'queue',
      header: 'In the queue',
      cell: ({ row }) =>
        row.original.due_reason
          ? renderComponent(DueBadge, { reason: row.original.due_reason, label: row.original.due_label })
          : '',
    },
  ])
</script>

<svelte:head><title>{starred ? 'Starred projects' : 'AI flags'} · Fallen Admin</title></svelte:head>

<div>
  <div class="mb-6">
    <h1 class="text-2xl font-semibold tracking-tight">{starred ? 'Starred projects' : 'AI flags'}</h1>
    <p class="text-sm text-muted-foreground">
      {#if starred}
        Projects reviewers starred as standouts in
        <Link href={journalReviewRoot().url} class="underline">journal review</Link>.
      {:else}
        Projects reviewers flagged as written by AI. They stay out of the
        <Link href={journalReviewRoot().url} class="underline">journal review</Link> queue until an admin opens
        one and clears the flag.
      {/if}
    </p>
  </div>

  <Deferred data={['projects', 'pagy']}>
    {#snippet fallback()}
      <DataTableSkeleton
        headers={['Project', 'By', 'Logged', starred ? 'Starred by' : 'Flagged by', 'When']}
      />
    {/snippet}
    <DataTable {columns} data={projects ?? []} {pagy} noun="projects" />
  </Deferred>
</div>
