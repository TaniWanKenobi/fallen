<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import Link from '@/components/Link.svelte'
  import type { ColumnDef } from '@tanstack/table-core'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import GrantActions from '@/components/admin/grants/GrantActions.svelte'
  import PayoutStatus from '@/components/admin/grants/PayoutStatus.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { renderComponent } from '@/components/admin/ui/data-table'
  import Deferred from '@/components/Deferred.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import { formatDateTime, timeAgo } from '@/lib/format'
  import { money } from '@/lib/submission'
  import { adminFlag, adminGrants, hcbConnectAdminGrants, reviewSubmissions } from '@/routes'
  import type { AdminGrantPayout, Pagy } from '@/types'

  let {
    payouts,
    pagy,
    totals,
    tab,
    hcb,
  }: {
    payouts?: AdminGrantPayout[]
    pagy?: Pagy
    totals?: { unsent: number; sent: number; unsent_count: number }
    tab: string
    hcb: {
      configured: boolean
      connected: boolean
      expires_at: string | null
      connected_by: { name: string; avatar: string } | null
      writes: boolean
      automatic: boolean
      flag: string
    }
  } = $props()

  const tabs = [
    { value: 'unsent', label: 'To send' },
    { value: 'sent', label: 'Sent' },
    { value: 'all', label: 'All' },
  ].map((t) => ({
    ...t,
    href: adminGrants.index({ query: t.value === 'unsent' ? {} : { tab: t.value } }).url,
  }))

  const canSend = $derived(hcb.configured && hcb.connected)

  const columns: ColumnDef<AdminGrantPayout>[] = $derived([
    {
      id: 'recipient',
      header: 'To',
      cell: ({ row }) => renderComponent(PersonChip, { person: row.original.recipient }),
    },
    { accessorKey: 'email', header: 'HCB email' },
    { id: 'project', header: 'Project', cell: ({ row }) => row.original.project_title },
    { id: 'amount', header: 'Amount', cell: ({ row }) => money(row.original.amount_cents) },
    {
      id: 'status',
      header: 'Status',
      cell: ({ row }) => renderComponent(PayoutStatus, { payout: row.original }),
    },
    {
      id: 'when',
      header: 'When',
      cell: ({ row }) =>
        row.original.sent_at
          ? formatDateTime(row.original.sent_at)
          : `approved ${timeAgo(row.original.created_at)}`,
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => renderComponent(GrantActions, { payout: row.original, canSend }),
    },
  ])
</script>

<svelte:head><title>Grants · Fallen Admin</title></svelte:head>

<div class="mb-5">
  <h1 class="text-2xl font-semibold tracking-tight">Grants</h1>
  <p class="text-sm text-muted-foreground">
    Funding for approved designs, sent as HCB card grants: one card per person, topped up by each approval.
    <Link href={reviewSubmissions.reviewRoot().url} class="underline">Design review queue</Link>
  </p>
</div>

<div class="mb-6 grid gap-4 md:grid-cols-3">
  <Card.Root>
    <Card.Header>
      <Card.Description>HCB</Card.Description>
      <Card.Title class="text-base">
        {#if !hcb.configured}
          Not set up
        {:else if hcb.connected}
          Connected
        {:else}
          Not connected
        {/if}
      </Card.Title>
    </Card.Header>
    <Card.Content class="space-y-2 text-sm text-muted-foreground">
      {#if !hcb.configured}
        <p>Set HCB_CLIENT_ID, HCB_CLIENT_SECRET and HCB_ORGANIZATION_ID.</p>
      {:else if hcb.connected && hcb.connected_by}
        <p>By {hcb.connected_by.name}. The token renews by itself.</p>
      {/if}
      {#if !hcb.writes}
        <p class="text-amber-600">
          Not production: sends are logged, not made. Set HCB_ALLOW_WRITES to send for real.
        </p>
      {/if}
      {#if hcb.configured}
        <Button size="sm" variant="outline" href={hcbConnectAdminGrants().url}
          >{hcb.connected ? 'Reconnect' : 'Connect HCB'}</Button
        >
      {/if}
    </Card.Content>
  </Card.Root>
  <Card.Root>
    <Card.Header>
      <Card.Description>Sending</Card.Description>
      <Card.Title class="text-base">{hcb.automatic ? 'Automatic' : 'By hand'}</Card.Title>
    </Card.Header>
    <Card.Content class="space-y-2 text-sm text-muted-foreground">
      <p>
        {hcb.automatic
          ? 'Each approval is sent as soon as the review is in.'
          : 'Approvals wait here until someone presses Send. Turn on the flag to send them as soon as they’re approved.'}
      </p>
      <Button size="sm" variant="outline" href={adminFlag(hcb.flag).url}>The {hcb.flag} flag</Button>
    </Card.Content>
  </Card.Root>
  <Card.Root>
    <Card.Header>
      <Card.Description>Totals</Card.Description>
      <Card.Title class="font-mono text-base">
        {totals ? money(totals.sent) : '...'}
        <span class="text-sm font-normal text-muted-foreground">sent</span>
      </Card.Title>
    </Card.Header>
    <Card.Content class="text-sm text-muted-foreground">
      {totals ? `${money(totals.unsent)} in ${totals.unsent_count} still to send` : ''}
    </Card.Content>
  </Card.Root>
</div>

<LinkTabs {tabs} active={tab} class="mb-4" />

<Deferred data={['payouts', 'pagy']}>
  {#snippet fallback()}
    <DataTableSkeleton headers={['To', 'HCB email', 'Project', 'Amount', 'Status', 'When', '']} />
  {/snippet}
  <DataTable {columns} data={payouts ?? []} {pagy} noun="payouts" />
</Deferred>
