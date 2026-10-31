<script lang="ts">
  import { Skeleton, SkulletProvider } from 'skullet/svelte'
  import { untrack, type Snippet } from 'svelte'

  // Shows `skeleton` while loading, then brings the content in with skullet's sweep reveal: one diagonal front at
  // the shimmer's slant and pace, as if the highlight crossing the placeholder left the content behind it.
  // skullet only sweeps away a skeleton it drew, so `skeleton` isn't shown as it is: skullet lays it out unseen and
  // draws a bone over each painted box in it (the <Skeleton> bars), shimmering on its own layer. Over about a screen
  // and a half skullet crossfades instead, and content already there on the first render shows at once.
  // The panes are skullet's wrapper divs, so put this where one block is expected, never among a grid's items.
  let {
    loading,
    skeleton,
    children,
    class: className,
  }: { loading: boolean; skeleton?: Snippet; children: Snippet; class?: string } = $props()

  // Content that came in over a skeleton has had its entrance, so a stagger-in inside it stays still (application.css)
  let swept = $state(untrack(() => loading))
  $effect.pre(() => {
    if (loading) swept = true
  })
</script>

<!-- `data` drives it, so the pane on its way out keeps the skeleton it was measured from -->
<SkulletProvider reveal="sweep">
  <Skeleton
    data={loading ? null : ('content' as const)}
    sample="skeleton"
    class={[className, swept && 'reveal-swept'].filter(Boolean).join(' ')}
  >
    {#snippet children(pane)}
      {#if pane === 'skeleton'}{@render skeleton?.()}{:else}{@render content()}{/if}
    {/snippet}
  </Skeleton>
</SkulletProvider>

{#snippet content()}{@render children()}{/snippet}
