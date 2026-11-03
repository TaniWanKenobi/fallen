<script lang="ts">
  import Hash from '@lucide/svelte/icons/hash'
  import Link from '@lucide/svelte/icons/link'
  import Type from '@lucide/svelte/icons/type'
  import type { Snippet } from 'svelte'
  import type { RepoSource } from '@/lib/repoFetch'
  import { MAX_TEXT_BYTES } from '@/lib/repoFileKinds'
  import { parseDelimited } from '@/lib/csv'
  import Spinner from './Spinner.svelte'

  // A CSV or TSV as a spreadsheet, after Fallout's Glide data grid (a React canvas grid): typed column headers,
  // numbered rows, resizable columns, hover and range selection, copy as TSV, double-click to read a long cell or
  // open a link. Rows are virtualised, so a big BOM scrolls as smoothly as a small one.
  let {
    path,
    source,
    dark,
    fallback,
  }: { path: string; source: RepoSource; dark: boolean; fallback: Snippet<[string?]> } = $props()

  const ROW = 32
  const HEADER = 34
  const MARKER = 44
  const OVERSCAN = 8

  type ColumnType = 'number' | 'url' | 'text'
  const NUMBER_RE = /^\s*[-+]?[$€£¥]?\s*(\d{1,3}(,\d{3})*|\d+)?(\.\d+)?\s*%?\s*$/
  const URL_RE = /^(https?:\/\/|www\.)\S+$/i
  const ICONS = { number: Hash, url: Link, text: Type }

  let head = $state<string[] | null>(null)
  let body = $state.raw<string[][]>([])
  let types = $state<ColumnType[]>([])
  let widths = $state<number[]>([])
  let note = $state<string | null>(null)
  let error = $state<string | null>(null)

  let scroller: HTMLDivElement | undefined = $state()
  let scrollTop = $state(0)
  let viewport = $state(600)
  let hover = $state<number | null>(null)
  // The selected range: anchor and the cell it was dragged or shifted to.
  let anchor = $state<[number, number] | null>(null)
  let focus = $state<[number, number] | null>(null)
  let dragging = false
  let overlay = $state<{ col: number; row: number; text: string } | null>(null)

  function inferType(values: string[]): ColumnType {
    const sample = values.filter((v) => v.trim() !== '').slice(0, 200)
    if (sample.length === 0) return 'text'
    if (sample.every((v) => URL_RE.test(v.trim()))) return 'url'
    if (sample.every((v) => NUMBER_RE.test(v) && /\d/.test(v))) return 'number'
    return 'text'
  }

  $effect(() => {
    let cancelled = false
    source.buffer(path).then(
      (bytes) => {
        if (cancelled) return
        if (bytes.byteLength > MAX_TEXT_BYTES) return (note = 'This file is too large to preview inline.')
        const rows = parseDelimited(new TextDecoder().decode(bytes), path.endsWith('.tsv') ? '\t' : ',')
        const [first, ...rest] = rows
        if (!first) return (note = 'This file is empty.')
        types = first.map((_, i) => inferType(rest.map((r) => r[i] ?? '')))
        widths = first.map((title, i) => {
          const longest = Math.max(title.length, ...rest.slice(0, 200).map((r) => (r[i] ?? '').length))
          return Math.min(types[i] === 'url' ? 320 : 420, Math.max(90, longest * 7.2 + 44))
        })
        body = rest
        head = first
      },
      (e: Error) => !cancelled && (error = e.message),
    )
    return () => (cancelled = true)
  })

  const first = $derived(Math.max(0, Math.floor(scrollTop / ROW) - OVERSCAN))
  const last = $derived(Math.min(body.length, Math.ceil((scrollTop + viewport) / ROW) + OVERSCAN))
  const range = $derived.by(() => {
    if (!anchor || !focus) return null
    return {
      c0: Math.min(anchor[0], focus[0]),
      c1: Math.max(anchor[0], focus[0]),
      r0: Math.min(anchor[1], focus[1]),
      r1: Math.max(anchor[1], focus[1]),
    }
  })
  const inRange = (c: number, r: number) =>
    !!range && c >= range.c0 && c <= range.c1 && r >= range.r0 && r <= range.r1

  // Sheets and Airtable colours, the theme Fallout gives Glide.
  const theme = $derived(
    dark
      ? {
          header: '#1f1f22',
          hovered: '#2a2a2e',
          border: '#2e2e33',
          accent: '#8ab4f8',
          wash: '#1c2a44',
        }
      : {
          header: '#f8f9fa',
          hovered: '#f1f3f4',
          border: '#e3e3e3',
          accent: '#1a73e8',
          wash: '#e8f0fe',
        },
  )

  function href(raw: string) {
    const value = raw.trim()
    return /^https?:\/\//i.test(value) ? value : `https://${value}`
  }

  function activate(col: number, row: number) {
    const value = body[row]?.[col] ?? ''
    if (types[col] === 'url') window.open(href(value), '_blank', 'noopener,noreferrer')
    else if (value) overlay = { col, row, text: value }
  }

  function select(col: number, row: number, extend: boolean) {
    overlay = null
    if (!extend || !anchor) anchor = [col, row]
    focus = [col, row]
    scroller?.focus({ preventScroll: true })
  }

  function reveal(col: number, row: number) {
    if (!scroller) return
    const top = row * ROW
    if (top < scroller.scrollTop) scroller.scrollTop = top
    else if (top + ROW > scroller.scrollTop + scroller.clientHeight - HEADER)
      scroller.scrollTop = top + ROW - scroller.clientHeight + HEADER
    const left = MARKER + widths.slice(0, col).reduce((a, b) => a + b, 0)
    if (left < scroller.scrollLeft + MARKER) scroller.scrollLeft = left - MARKER
    else if (left + widths[col] > scroller.scrollLeft + scroller.clientWidth)
      scroller.scrollLeft = left + widths[col] - scroller.clientWidth
  }

  function onkeydown(event: KeyboardEvent) {
    if (!focus || !head) return
    const mod = event.metaKey || event.ctrlKey
    if (mod && event.key.toLowerCase() === 'c' && range) {
      event.preventDefault()
      const lines = []
      for (let r = range.r0; r <= range.r1; r++) lines.push(body[r].slice(range.c0, range.c1 + 1).join('\t'))
      void navigator.clipboard.writeText(lines.join('\n'))
      return
    }
    if (mod && event.key.toLowerCase() === 'a') {
      event.preventDefault()
      anchor = [0, 0]
      focus = [head.length - 1, body.length - 1]
      return
    }
    const moves: Record<string, [number, number]> = {
      ArrowUp: [0, -1],
      ArrowDown: [0, 1],
      ArrowLeft: [-1, 0],
      ArrowRight: [1, 0],
      Tab: [event.shiftKey ? -1 : 1, 0],
    }
    const move = moves[event.key]
    if (move) {
      event.preventDefault()
      event.stopPropagation()
      const col = Math.min(head.length - 1, Math.max(0, focus[0] + move[0]))
      const row = Math.min(body.length - 1, Math.max(0, focus[1] + move[1]))
      select(col, row, event.shiftKey && event.key !== 'Tab')
      reveal(col, row)
    } else if (event.key === 'Enter') {
      event.preventDefault()
      activate(focus[0], focus[1])
    } else if (event.key === 'Escape' && overlay) {
      event.stopPropagation()
      overlay = null
    }
  }

  function resize(event: PointerEvent, col: number) {
    event.preventDefault()
    event.stopPropagation()
    const start = event.clientX
    const from = widths[col]
    const target = event.currentTarget as HTMLElement
    target.setPointerCapture(event.pointerId)
    const move = (e: PointerEvent) => (widths[col] = Math.max(50, from + e.clientX - start))
    const up = () => {
      target.removeEventListener('pointermove', move)
      target.removeEventListener('pointerup', up)
    }
    target.addEventListener('pointermove', move)
    target.addEventListener('pointerup', up)
  }
</script>

<svelte:window onpointerup={() => (dragging = false)} />

{#if error}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t load this file ({error}).</p>
{:else if note}
  {@render fallback(note)}
{:else if !head}
  <Spinner />
{:else}
  <div
    bind:this={scroller}
    bind:clientHeight={viewport}
    class="csv-grid relative h-full w-full overflow-auto bg-background text-[13px] outline-none select-none"
    style:--grid-header={theme.header}
    style:--grid-hovered={theme.hovered}
    style:--grid-border={theme.border}
    style:--grid-accent={theme.accent}
    style:--grid-wash={theme.wash}
    tabindex="0"
    role="grid"
    aria-rowcount={body.length + 1}
    aria-colcount={head.length}
    onscroll={() => (scrollTop = scroller!.scrollTop)}
    {onkeydown}
    onpointerleave={() => (hover = null)}
  >
    <table
      class="table-fixed border-separate border-spacing-0"
      style:width="{MARKER + widths.reduce((a, b) => a + b, 0)}px"
    >
      <colgroup>
        <col style:width="{MARKER}px" />
        {#each widths as width, i (i)}<col style:width="{width}px" />{/each}
      </colgroup>
      <thead>
        <tr style:height="{HEADER}px">
          <th class="corner sticky top-0 left-0 z-30"></th>
          {#each head as title, c (c)}
            {@const Icon = ICONS[types[c]]}
            {@const active = !!range && c >= range.c0 && c <= range.c1}
            <th
              class={['sticky top-0 z-20 px-2.5 text-left text-xs font-semibold', active && 'active']}
              onpointerdown={() => {
                anchor = [c, 0]
                focus = [c, body.length - 1]
                overlay = null
                scroller?.focus({ preventScroll: true })
              }}
            >
              <span class="flex min-w-0 items-center gap-1.5">
                <span class="type-icon grid size-4 shrink-0 place-items-center rounded-[4px]">
                  <Icon class="size-3" strokeWidth={2.5} />
                </span>
                <span class="truncate">{title || `Column ${c + 1}`}</span>
              </span>
              <!-- svelte-ignore a11y_no_static_element_interactions -->
              <span
                class="resizer absolute top-0 -right-1 z-10 h-full w-2 cursor-col-resize"
                onpointerdown={(e) => resize(e, c)}
              ></span>
            </th>
          {/each}
        </tr>
      </thead>
      <tbody>
        {#if first > 0}<tr style:height="{first * ROW}px"><td colspan={head.length + 1}></td></tr>{/if}
        {#each body.slice(first, last) as cells, i (first + i)}
          {@const r = first + i}
          {@const rowActive = !!range && r >= range.r0 && r <= range.r1}
          <tr style:height="{ROW}px" class={[hover === r && 'hovered']} onpointerenter={() => (hover = r)}>
            <td
              class={['marker sticky left-0 z-10 text-center text-xs tabular-nums', rowActive && 'active']}
              onpointerdown={() => {
                anchor = [0, r]
                focus = [head!.length - 1, r]
                overlay = null
                scroller?.focus({ preventScroll: true })
              }}>{r + 1}</td
            >
            {#each head as _, c (c)}
              {@const value = cells[c] ?? ''}
              {@const focused = focus?.[0] === c && focus?.[1] === r}
              <td
                class={[
                  'cell relative truncate px-2.5',
                  types[c] === 'number' && 'text-right',
                  types[c] === 'url' && 'url',
                  inRange(c, r) && !focused && 'selected',
                  focused && 'focused',
                ]}
                onpointerdown={(e) => {
                  if (e.button !== 0) return
                  dragging = true
                  select(c, r, e.shiftKey)
                }}
                onpointerenter={() => dragging && (focus = [c, r])}
                ondblclick={() => activate(c, r)}
                title={value.length > 40 ? value : undefined}
                >{types[c] === 'number' ? value.trim() : value}</td
              >
            {/each}
          </tr>
        {/each}
        {#if last < body.length}<tr style:height="{(body.length - last) * ROW}px"
            ><td colspan={head.length + 1}></td></tr
          >{/if}
      </tbody>
    </table>

    {#if overlay}
      {@const left = MARKER + widths.slice(0, overlay.col).reduce((a, b) => a + b, 0)}
      <div
        class="absolute z-40 max-h-64 w-80 overflow-auto rounded-md border bg-background p-2.5 text-[13px] whitespace-pre-wrap shadow-lg select-text"
        style:left="{left}px"
        style:top="{HEADER + overlay.row * ROW}px"
        style:border-color="var(--grid-accent)"
      >
        {overlay.text}
      </div>
    {/if}
  </div>
{/if}

<style>
  .csv-grid th {
    position: sticky;
    background: var(--grid-header);
    color: var(--muted-foreground);
    border-right: 1px solid var(--grid-border);
    border-bottom: 1px solid var(--grid-border);
  }
  .csv-grid th:hover:not(.corner) {
    background: var(--grid-hovered);
  }
  .csv-grid th.active,
  .csv-grid td.marker.active {
    background: var(--grid-wash);
    color: var(--grid-accent);
  }
  .csv-grid .type-icon {
    background: var(--muted-foreground);
    color: var(--background);
  }
  .csv-grid th.active .type-icon {
    background: var(--grid-accent);
  }
  .csv-grid td {
    border-right: 1px solid var(--grid-border);
    border-bottom: 1px solid var(--grid-border);
    background: var(--background);
    color: var(--foreground);
  }
  .csv-grid td.marker {
    background: var(--grid-header);
    color: var(--muted-foreground);
  }
  .csv-grid tr.hovered td.cell {
    background: var(--grid-hovered);
  }
  .csv-grid td.selected {
    background: var(--grid-wash) !important;
  }
  .csv-grid td.focused {
    box-shadow: inset 0 0 0 2px var(--grid-accent);
    border-radius: 4px;
  }
  .csv-grid td.url {
    color: var(--grid-accent);
    cursor: pointer;
  }
  .csv-grid td.url:hover {
    text-decoration: underline;
  }
  .csv-grid .resizer:hover {
    background: var(--grid-accent);
    opacity: 0.5;
  }
</style>
