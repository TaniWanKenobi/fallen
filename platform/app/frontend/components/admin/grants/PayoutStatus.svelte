<script lang="ts">
  import type { AdminGrantPayout } from '@/types'

  let { payout }: { payout: AdminGrantPayout } = $props()
  const STYLES = {
    pending: 'bg-zinc-100 text-zinc-700 dark:bg-zinc-800 dark:text-zinc-300',
    sending: 'bg-sky-100 text-sky-700 dark:bg-sky-950 dark:text-sky-300',
    sent: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400',
    failed: 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400',
  }
</script>

<span class="flex flex-col gap-0.5">
  <span class="w-fit rounded px-1.5 py-0.5 text-[11px] font-medium capitalize {STYLES[payout.status]}"
    >{payout.status === 'pending' ? 'unsent' : payout.status}{payout.status === 'sent' &&
    payout.via === 'manual'
      ? ' by hand'
      : ''}</span
  >
  {#if payout.error}<span class="max-w-80 text-xs text-red-600">{payout.error}</span>{/if}
</span>
