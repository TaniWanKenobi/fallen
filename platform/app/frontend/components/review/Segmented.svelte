<script lang="ts" generics="T extends string">
  import '@/components/review/review.css'
  import type { ReviewTabTint } from '@/components/review/ReviewTabBar.svelte'

  // A small choice in the review tab bar's look: a muted track with the picked option raised on a pill, its label
  // in the option's tint. Used for every call on the review page (rubric answers, journal time, parts).
  let {
    options,
    value,
    onChange,
    label,
    disabled = false,
    size = 'sm',
  }: {
    options: { value: T; label: string; tint: ReviewTabTint; title?: string }[]
    value: T | null | undefined
    onChange: (value: T) => void
    label: string
    disabled?: boolean
    size?: 'sm' | 'xs'
  } = $props()
</script>

<div class="seg" role="radiogroup" aria-label={label} data-size={size}>
  {#each options as option (option.value)}
    {@const on = option.value === value}
    <button
      type="button"
      role="radio"
      aria-checked={on}
      {disabled}
      title={option.title}
      data-tint={option.tint}
      class="seg-item"
      onclick={() => onChange(option.value)}>{option.label}</button
    >
  {/each}
</div>

<style>
  .seg {
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 0.1rem;
    padding: 0.18rem;
    border-radius: 999px;
    background: var(--muted);
  }
  .seg-item {
    border-radius: 999px;
    padding: 0.2rem 0.65rem;
    font-size: 0.75rem;
    font-weight: 600;
    white-space: nowrap;
    color: var(--foreground);
    opacity: 0.5;
    transition:
      opacity 120ms ease-out,
      background-color 120ms ease-out,
      box-shadow 120ms ease-out;
  }
  .seg[data-size='xs'] .seg-item {
    padding: 0.12rem 0.5rem;
    font-size: 0.7rem;
  }
  .seg-item:hover:not(:disabled):not([aria-checked='true']) {
    opacity: 0.8;
  }
  .seg-item:disabled {
    cursor: default;
  }
  .seg-item:focus-visible {
    outline: 2px solid var(--ring);
    outline-offset: 1px;
  }
  .seg-item[aria-checked='true'] {
    opacity: 1;
    background: var(--card);
    box-shadow: var(--rc-shadow-raise);
  }
  .seg-item[aria-checked='true'][data-tint='green'] {
    color: var(--rc-chip-green-ink);
  }
  .seg-item[aria-checked='true'][data-tint='amber'] {
    color: var(--rc-chip-amber-ink);
  }
  .seg-item[aria-checked='true'][data-tint='blue'] {
    color: var(--rc-chip-blue-ink);
  }
  .seg-item[aria-checked='true'][data-tint='violet'] {
    color: var(--rc-chip-violet-ink);
  }
  .seg-item[aria-checked='true'][data-tint='red'] {
    color: var(--rc-chip-red-ink);
  }
  .seg-item[aria-checked='true'][data-tint='gray'] {
    color: var(--rc-chip-gray-ink);
  }
</style>
