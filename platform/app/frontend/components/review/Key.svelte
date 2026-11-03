<script lang="ts">
  import type { Snippet } from 'svelte'
  import { cn } from '@/lib/utils'

  // Fallout's keyboard-key hint. `muted` for light surfaces (the top bar, outline buttons); `tooltip` for dark ones.
  let {
    variant = 'muted',
    class: className = '',
    children,
  }: { variant?: 'muted' | 'tooltip'; class?: string; children: Snippet } = $props()
</script>

<kbd
  class={cn(
    'inline-flex h-4 min-w-4 items-center justify-center rounded-sm border px-1 font-mono text-[10px] font-medium tracking-wide uppercase',
    variant === 'tooltip'
      ? 'border-background/30 bg-background/15 text-background'
      : 'border-foreground/20 bg-foreground/8 text-foreground/70',
    className,
  )}>{@render children()}</kbd
>
