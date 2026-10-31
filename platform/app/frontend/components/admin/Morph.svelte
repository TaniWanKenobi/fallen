<script lang="ts">
  import { onMount } from 'svelte'
  import type { TextMorph } from 'torph'

  // Text that changes in place, morphing from the old value to the new one (torph). Numbers roll by place value, so
  // 1,204 to 1,318 moves the hundreds and tens and leaves the thousands alone. torph is imported when the first one
  // mounts: bundled, it lands in a chunk the public pages share. Until then the text is shown as it is.
  let { text, class: className = '' }: { text: string | number; class?: string } = $props()

  let node: HTMLSpanElement
  let morph: TextMorph | undefined = $state.raw()

  onMount(() => {
    let gone = false
    import('torph').then(({ TextMorph }) => {
      if (gone) return
      // its first render keeps text nodes already there, so it starts from an empty element
      node.textContent = ''
      morph = new TextMorph({ element: node })
    })
    return () => {
      gone = true
      morph?.destroy()
    }
  })

  $effect(() => {
    if (morph) morph.update(String(text))
    else node.textContent = String(text)
  })
</script>

<span bind:this={node} class={className}></span>
