<script lang="ts" module>
  import type { TextMorph } from 'torph'

  // Fetched as soon as a page that uses Morph loads, so it is usually here before the numbers are
  let Morpher: typeof TextMorph | undefined
  const loading = import('torph').then((module) => (Morpher = module.TextMorph))
</script>

<script lang="ts">
  import { onMount } from 'svelte'

  // Text that changes in place, morphing from the old value to the new one (torph). Numbers roll by place value, so
  // 1,204 to 1,318 moves the hundreds and tens and leaves the thousands alone. It starts from nothing, so the first
  // value arrives with the same animation. torph is imported rather than bundled: bundled, it lands in a chunk the
  // public pages share.
  let { text, class: className = '' }: { text: string | number; class?: string } = $props()

  let node: HTMLSpanElement
  let morph: TextMorph | undefined = $state.raw()
  // hidden until torph is ready, so a first visit never shows the value once plain and again animated
  let waiting = $state(!Morpher)
  // torph owns the element from here, even in the frame before `morph` is set
  let started = false

  onMount(() => {
    let gone = false
    let instance: TextMorph | undefined
    const start = (Class: typeof TextMorph) => {
      if (gone) return
      // Its first render is never animated, keeps any text node already there, and skips a value equal to its
      // starting '': so an empty element, then a zero-width space, and the value comes in over that
      started = true
      node.textContent = ''
      instance = new Class({ element: node })
      instance.update('\u200B')
      waiting = false
      requestAnimationFrame(() => {
        if (!gone) morph = instance
      })
    }
    if (Morpher) start(Morpher)
    else loading.then(start, () => (waiting = false))
    return () => {
      gone = true
      instance?.destroy()
    }
  })

  $effect(() => {
    if (morph) morph.update(String(text))
    else if (!started) node.textContent = String(text)
  })
</script>

<span bind:this={node} class={[className, waiting && 'invisible']}></span>
