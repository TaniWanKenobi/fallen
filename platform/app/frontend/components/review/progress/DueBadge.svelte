<script lang="ts">
  // Why a project is waiting for journal review (ProgressStatus::DUE_REASONS).
  let { reason, label }: { reason: string | null; label: string | null } = $props()

  const tint: Record<string, string> = {
    requested: 'bg-pink-100 text-pink-700 dark:bg-pink-950 dark:text-pink-300',
    added: 'bg-zinc-200 text-zinc-800 dark:bg-zinc-800 dark:text-zinc-200',
    first: 'bg-sky-100 text-sky-700 dark:bg-sky-950 dark:text-sky-300',
    approved: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300',
    check_back: 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300',
    submitted: 'bg-violet-100 text-violet-700 dark:bg-violet-950 dark:text-violet-300',
  }
</script>

{#if reason && label}
  <span class={['rounded px-1.5 py-0.5 text-[11px] font-medium whitespace-nowrap', tint[reason]]}
    >{label}</span
  >
{/if}
