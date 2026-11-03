<script lang="ts" module>
  import type { NumoraInput as Numora } from 'numora'
  import type { TextMorph } from 'torph'
  import { chunk } from '@/lib/chunks'

  // Both arrive together, after the page: neither is in a page's own bundle.
  type Libraries = { NumoraInput: typeof Numora; TextMorph: typeof TextMorph }
  let libraries: Libraries | undefined
  const loading = Promise.all([chunk(import('numora')), chunk(import('torph'))]).then(
    ([numora, torph]) => (libraries = { NumoraInput: numora.NumoraInput, TextMorph: torph.TextMorph }),
  )
</script>

<script lang="ts">
  import { onMount } from 'svelte'

  // A number field whose digits morph as they're typed (numora's torph integration): a real <input> with see-through
  // text sits over a torph element showing the same value, so the input keeps the keyboard, caret, selection, undo
  // and paste, and numora keeps the value a clean number. `value` is the raw number as a string ('' when empty).
  // The field's look (padding, font, alignment) goes on `class`; the input copies it, so the two line up.
  let {
    value = $bindable(),
    decimals = 2,
    separators = false,
    max,
    placeholder = '',
    align = 'left',
    disabled = false,
    label,
    class: className = '',
    onfocus,
    onchange,
    ref = $bindable(),
  }: {
    value: string
    decimals?: number
    separators?: boolean
    max?: number
    placeholder?: string
    align?: 'left' | 'right'
    disabled?: boolean
    label: string
    class?: string
    onfocus?: () => void
    // Only for what the person types, not for changes made from outside.
    onchange?: (value: string) => void
    ref?: HTMLInputElement
  } = $props()

  let host: HTMLDivElement
  let display: HTMLSpanElement
  let numora: Numora | undefined = $state.raw()
  let morph: TextMorph | undefined

  onMount(() => {
    let gone = false
    let cleanup = () => {}
    const start = ({ NumoraInput, TextMorph }: Libraries) => {
      if (gone) return
      display.textContent = ''
      const instance = new NumoraInput(host, {
        value,
        decimalMaxLength: decimals,
        thousandSeparator: ',',
        thousandStyle: (separators ? 'thousand' : 'none') as never,
        formatOn: 'change' as never,
        rawValueMode: true,
        inputMode: decimals > 0 ? 'decimal' : 'numeric',
        isAllowed: (raw: string) => max == null || raw === '' || Number(raw) <= max,
      })
      const input = instance.getElement()
      input.setAttribute('aria-label', label)
      input.placeholder = placeholder
      input.disabled = disabled
      input.autocomplete = 'off'
      ref = input
      morph = new TextMorph({ element: display, ease: { stiffness: 400, damping: 30 } })
      morph.update(input.value)
      // numora writes its formatted value during beforeinput, so read it once that handler has run.
      const sync = () => {
        morph?.update(input.value)
        const raw = instance.getValue()
        if (raw !== value) {
          value = raw
          onchange?.(raw)
        }
      }
      const later = () => queueMicrotask(sync)
      const focus = () => onfocus?.()
      input.addEventListener('beforeinput', later)
      input.addEventListener('input', sync)
      input.addEventListener('focus', focus)
      numora = instance
      cleanup = () => {
        input.removeEventListener('beforeinput', later)
        input.removeEventListener('input', sync)
        input.removeEventListener('focus', focus)
        morph?.destroy()
        input.remove()
      }
    }
    if (libraries) start(libraries)
    else loading.then(start, () => {})
    return () => {
      gone = true
      cleanup()
    }
  })

  // Changes made from outside (a quick pick, a CSV import) go into the input as well as the display.
  $effect(() => {
    const next = value ?? ''
    if (!numora || numora.getValue() === next) return
    numora.setValue(next, { undoable: false })
    morph?.update(numora.getElement().value)
  })

  $effect(() => {
    if (numora) numora.getElement().disabled = disabled
  })
</script>

<div class={['number-input', align === 'right' && 'is-right', disabled && 'is-disabled', className]}>
  <span bind:this={display} class="number-display" aria-hidden="true">{value}</span>
  {#if !value && placeholder}<span class="number-placeholder" aria-hidden="true">{placeholder}</span>{/if}
  <div bind:this={host} class="number-host"></div>
</div>

<style>
  .number-input {
    position: relative;
    display: flex;
    align-items: center;
    overflow: hidden;
    cursor: text;
    font-variant-numeric: tabular-nums;
  }
  .is-right {
    justify-content: flex-end;
  }
  .is-disabled {
    cursor: default;
  }
  .number-display,
  .number-placeholder {
    pointer-events: none;
    white-space: pre;
  }
  .number-placeholder {
    position: absolute;
    opacity: 0.45;
  }
  /* Same padding as the field (passed on to the input, which covers all of it), so the input's text starts exactly
     where the display's does and a click anywhere in the field lands in it. */
  .number-host {
    position: absolute;
    inset: 0;
    padding: inherit;
  }
  /* The real input: its text is invisible (torph shows it), its caret and selection are not. */
  .number-host :global(input) {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    margin: 0;
    padding: inherit;
    border: 0;
    border-radius: inherit;
    background: transparent;
    color: transparent;
    caret-color: currentColor;
    font: inherit;
    letter-spacing: inherit;
    text-align: left;
    outline: none;
    box-shadow: none;
  }
  .is-right .number-host :global(input) {
    text-align: right;
  }
  .number-host :global(input::selection) {
    background: color-mix(in oklch, currentColor 25%, transparent);
  }
  .number-host :global(input::placeholder) {
    color: transparent;
  }
</style>
