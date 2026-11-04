<script lang="ts">
  // A journal review's decision (ProgressReview::VERDICTS).
  let { verdict }: { verdict: 'approved' | 'check_back' | 'dismissed' } = $props()

  const shown = {
    approved: ['Approved', 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300'],
    check_back: ['Check back', 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'],
    dismissed: ['Dismissed', 'bg-muted text-muted-foreground'],
  } as const
</script>

<span class={['rounded px-1.5 py-0.5 text-[11px] font-medium whitespace-nowrap', shown[verdict][1]]}
  >{shown[verdict][0]}</span
>
