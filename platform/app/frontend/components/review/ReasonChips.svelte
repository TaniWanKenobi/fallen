<script lang="ts">
  // The fixed reasons a reviewer picks from (journal deflations, lowered or cut parts), one click each, so reviews
  // stay comparable.
  let {
    reasons,
    value,
    onChange,
    label,
    disabled = false,
  }: {
    reasons: string[]
    value: string | null
    onChange: (reason: string) => void
    label: string
    disabled?: boolean
  } = $props()
</script>

<div class="flex min-w-0 flex-1 flex-wrap gap-1" role="radiogroup" aria-label={label}>
  {#each reasons as reason (reason)}
    {@const on = value === reason}
    <button
      type="button"
      role="radio"
      aria-checked={on}
      {disabled}
      onclick={() => onChange(reason)}
      class={[
        'rounded-full border px-2.5 py-0.5 text-xs transition-all duration-200 disabled:cursor-default',
        on
          ? 'border-transparent bg-card font-semibold text-foreground shadow-[var(--rc-shadow-raise)]'
          : 'border-border text-muted-foreground hover:border-foreground/30 hover:text-foreground',
      ]}>{reason}</button
    >
  {/each}
</div>
