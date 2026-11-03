<script lang="ts">
  let { status, class: className = '' }: { status: string; class?: string } = $props()

  const STYLES: Record<string, string> = {
    pending: 'bg-zinc-100 text-zinc-700 dark:bg-zinc-800 dark:text-zinc-300',
    approved: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400',
    returned: 'bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-400',
    rejected: 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400',
    withdrawn: 'bg-zinc-100 text-zinc-500 dark:bg-zinc-800 dark:text-zinc-400',
  }
</script>

<span
  class="inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-medium capitalize {STYLES[status] ??
    STYLES.pending} {className}">{status}</span
>
