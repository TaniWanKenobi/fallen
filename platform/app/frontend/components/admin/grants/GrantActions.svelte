<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Button } from '@/components/admin/ui/button'
  import { Input } from '@/components/admin/ui/input'
  import { money } from '@/lib/submission'
  import { markSentAdminGrant, retryAdminGrant, sendNowAdminGrant } from '@/routes'
  import type { AdminGrantPayout } from '@/types'

  let { payout, canSend }: { payout: AdminGrantPayout; canSend: boolean } = $props()
  let reference = $state('')

  const post = (url: string, data = {}) => router.post(url, data, { preserveScroll: true })
</script>

<div class="flex flex-wrap justify-end gap-1.5">
  {#if payout.status === 'pending' && canSend}
    <AlertDialog.Root>
      <AlertDialog.Trigger>
        {#snippet child({ props })}<Button {...props} size="sm">Send via HCB</Button>{/snippet}
      </AlertDialog.Trigger>
      <AlertDialog.Content>
        <AlertDialog.Header>
          <AlertDialog.Title>Send {money(payout.amount_cents)} to {payout.recipient.name}?</AlertDialog.Title>
          <AlertDialog.Description>
            It goes to {payout.email} as an HCB card grant: a new card if they have none, or a top-up of theirs.
          </AlertDialog.Description>
        </AlertDialog.Header>
        <AlertDialog.Footer>
          <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
          <AlertDialog.Action onclick={() => post(sendNowAdminGrant(payout.id).url)}
            >Send it</AlertDialog.Action
          >
        </AlertDialog.Footer>
      </AlertDialog.Content>
    </AlertDialog.Root>
  {/if}
  {#if payout.status === 'failed' || payout.status === 'sending'}
    <AlertDialog.Root>
      <AlertDialog.Trigger>
        {#snippet child({ props })}<Button {...props} size="sm" variant="outline">It didn’t go through</Button
          >{/snippet}
      </AlertDialog.Trigger>
      <AlertDialog.Content>
        <AlertDialog.Header>
          <AlertDialog.Title>Checked HCB first?</AlertDialog.Title>
          <AlertDialog.Description>
            Look for a card grant or top-up of {money(payout.amount_cents)} to {payout.email} on HCB. Only put this
            back to unsent if there isn’t one, or they’ll be paid twice.
          </AlertDialog.Description>
        </AlertDialog.Header>
        <AlertDialog.Footer>
          <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
          <AlertDialog.Action onclick={() => post(retryAdminGrant(payout.id).url)}
            >There isn’t one</AlertDialog.Action
          >
        </AlertDialog.Footer>
      </AlertDialog.Content>
    </AlertDialog.Root>
  {/if}
  {#if payout.status !== 'sent'}
    <AlertDialog.Root>
      <AlertDialog.Trigger>
        {#snippet child({ props })}<Button {...props} size="sm" variant="ghost">Mark sent</Button>{/snippet}
      </AlertDialog.Trigger>
      <AlertDialog.Content>
        <AlertDialog.Header>
          <AlertDialog.Title>Sent on HCB by hand?</AlertDialog.Title>
          <AlertDialog.Description
            >For a grant you made on HCB yourself, or a failed send that did go through.</AlertDialog.Description
          >
        </AlertDialog.Header>
        <Input bind:value={reference} placeholder="HCB card grant id or link (optional)" />
        <AlertDialog.Footer>
          <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
          <AlertDialog.Action onclick={() => post(markSentAdminGrant(payout.id).url, { reference })}
            >Mark sent</AlertDialog.Action
          >
        </AlertDialog.Footer>
      </AlertDialog.Content>
    </AlertDialog.Root>
  {/if}
</div>
