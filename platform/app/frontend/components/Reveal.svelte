<script lang="ts">
  import { Skeleton, SkulletProvider } from 'skullet/svelte'
  import { untrack, type Snippet } from 'svelte'

  // Shows `skeleton` while loading, then brings the content in behind skullet's sweep: one diagonal front at the
  // shimmer's slant and pace, so the content seems to arrive with the highlight that was crossing its placeholder.
  // Content already there on the first render shows at once. The two sit in skullet's own wrapper divs, so put this
  // where one block is expected, never among a grid's or a flex row's items.
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

<SkulletProvider reveal="sweep">
  <Skeleton
    {loading}
    {skeleton}
    {children}
    class={[className, swept && 'reveal-swept'].filter(Boolean).join(' ')}
  />
</SkulletProvider>
