<script lang="ts">
  import { onMount } from 'svelte'
  import type { TextMorph } from 'torph'

  // Text that changes in place, morphing from the old value to the new one (torph). Numbers roll by place value, so
  // 1,204 to 1,318 moves the hundreds and tens and leaves the thousands alone. It starts from nothing, so the first
  // value arrives with the same animation. torph is imported when the first one mounts: bundled, it lands in a chunk
  // the public pages share. Until then the text is shown as it is.
  let { text, class: className = '' }: { text: string | number; class?: string } = $props()

  let node: HTMLSpanElement
  let morph: TextMorph | undefined = $state.raw()
  // hidden until torph is ready, so a first visit never shows the value once plain and again animated
  let waiting = $state(true)

  onMount(() => {
    let gone = false
    let instance: TextMorph | undefined
    import('torph')
      .then(({ TextMorph }) => {
        if (gone) return
        // its first render keeps text nodes already there, and is never animated: so an empty one, then the value
        node.textContent = ''
        instance = new TextMorph({ element: node })
        instance.update('')
        requestAnimationFrame(() => {
          if (!gone) morph = instance
        })
      })
      .finally(() => (waiting = false))
    return () => {
      gone = true
      instance?.destroy()
    }
  })

  $effect(() => {
    if (morph) morph.update(String(text))
    else node.textContent = String(text)
  })
</script>

<span bind:this={node} class={[className, waiting && 'invisible']}></span>
