<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import type { ColumnDef } from '@tanstack/table-core'
  import Download from '@lucide/svelte/icons/download'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import Deferred from '@/components/Deferred.svelte'
  import { formatDateTime } from '@/lib/format'
  import { adminWorkshopRsvps, exportAdminWorkshopRsvps, workshopRsvp } from '@/routes'
  import type { AdminWorkshopRsvp, Pagy } from '@/types'

  type Slot = { key: string; starts_at: string; ends_at: string }

  let {
    title,
    slots,
    slot,
    counts,
    rsvps,
    pagy,
  }: {
    title: string
    slots: Slot[]
    slot: string | null
    counts?: Record<string, number>
    rsvps?: AdminWorkshopRsvp[]
    pagy?: Pagy
  } = $props()

  // Shown in Eastern, the time the invite email gives.
  const eastern = new Intl.DateTimeFormat(undefined, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZone: 'America/New_York',
    timeZoneName: 'short',
  })
  const slotLabel = (key: string) => {
    const found = slots.find((s) => s.key === key)
    return found ? eastern.format(new Date(found.starts_at)) : key
  }
  const total = $derived(counts ? Object.values(counts).reduce((sum, n) => sum + n, 0) : null)

  const tabs = $derived([
    { value: 'all', label: 'All', href: adminWorkshopRsvps.index().url },
    ...slots.map((s) => ({
      value: s.key,
      label: slotLabel(s.key),
      href: adminWorkshopRsvps.index({ query: { slot: s.key } }).url,
    })),
  ])
  const csvUrl = $derived(exportAdminWorkshopRsvps({ query: slot ? { slot } : {} }).url)

  const columns: ColumnDef<AdminWorkshopRsvp>[] = [
    { accessorKey: 'email', header: 'Email' },
    { id: 'slack', header: 'Slack', cell: ({ row }) => row.original.slack_username ?? '' },
    { id: 'slot', header: 'Time', cell: ({ row }) => slotLabel(row.original.slot) },
    { id: 'when', header: 'Signed up', cell: ({ row }) => formatDateTime(row.original.created_at) },
  ]
</script>

<svelte:head><title>Workshop RSVPs · Fallen Admin</title></svelte:head>

<div class="mb-5 flex flex-wrap items-end justify-between gap-3">
  <div>
    <h1 class="text-2xl font-semibold tracking-tight">Workshop RSVPs</h1>
    <p class="text-sm text-muted-foreground">
      {title}. Sign-ups from <a href={workshopRsvp().url} class="underline">the RSVP page</a>, which needs no
      account, so none of them count in Stats.
    </p>
  </div>
  <Button size="sm" variant="outline" href={csvUrl} download>
    <Download class="size-4" /> CSV{slot ? ` for ${slotLabel(slot)}` : ''}
  </Button>
</div>

<div class="mb-6 grid gap-4 md:grid-cols-3">
  <Card.Root>
    <Card.Header>
      <Card.Description>Total</Card.Description>
      <Card.Title class="font-mono text-2xl">{total ?? '...'}</Card.Title>
    </Card.Header>
  </Card.Root>
  {#each slots as s (s.key)}
    <Card.Root>
      <Card.Header>
        <Card.Description>{slotLabel(s.key)}</Card.Description>
        <Card.Title class="font-mono text-2xl">{counts ? (counts[s.key] ?? 0) : '...'}</Card.Title>
      </Card.Header>
    </Card.Root>
  {/each}
</div>

<LinkTabs {tabs} active={slot ?? 'all'} class="mb-4" />

<Deferred data={['rsvps', 'pagy']}>
  {#snippet fallback()}
    <DataTableSkeleton headers={['Email', 'Slack', 'Time', 'Signed up']} />
  {/snippet}
  <DataTable {columns} data={rsvps ?? []} {pagy} noun="sign-ups" />
</Deferred>
