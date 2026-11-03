<script lang="ts" module>
  const KICANVAS_SRC = '/vendor/kicanvas/kicanvas.js'
  let kicanvasLoad: Promise<void> | null = null

  function loadKiCanvas() {
    if (customElements.get('kicanvas-embed')) return Promise.resolve()
    kicanvasLoad ??= new Promise<void>((resolve, reject) => {
      const script = document.createElement('script')
      script.type = 'module'
      script.src = KICANVAS_SRC
      script.onload = () => customElements.whenDefined('kicanvas-embed').then(() => resolve())
      script.onerror = () => {
        kicanvasLoad = null
        reject(new Error('Failed to load KiCanvas'))
      }
      document.head.appendChild(script)
    })
    return kicanvasLoad
  }
</script>

<script lang="ts">
  import type { RepoSource } from '@/lib/repoFetch'
  import { fileName } from '@/lib/repoFileKinds'
  import Spinner from './Spinner.svelte'

  // KiCad schematics, boards and projects in KiCanvas (MIT, Alethea Flowers), vendored at public/vendor/kicanvas so
  // nothing loads from another origin (Fallout's KiCadViewer). KiCanvas can't list the repo itself, so the file,
  // every sub-sheet it names and the project beside it are fetched first and handed to it inline.
  let { path, source, dark }: { path: string; source: RepoSource; dark: boolean } = $props()

  function sheetfiles(sch: string): string[] {
    return [...sch.matchAll(/\(property\s+"Sheetfile"\s+"([^"]+)"/g)].map((m) => m[1])
  }

  // A path in the repo for a name KiCad wrote: next to the file first, then any file with that name.
  function resolve(dir: string, name: string): string | null {
    if (source.paths.has(dir + name)) return dir + name
    for (const p of source.paths) if (fileName(p) === name) return p
    return null
  }

  async function collectSources(): Promise<Map<string, string>> {
    const dir = path.includes('/') ? path.slice(0, path.lastIndexOf('/') + 1) : ''
    const rootText = await source.text(path)
    const sources = new Map<string, string>([
      [path, rootText],
      [path.slice(dir.length), rootText],
    ])
    let pending = new Set(sheetfiles(rootText))
    const seen = new Set(pending)
    while (pending.size > 0) {
      const level = [...pending]
      pending = new Set()
      await Promise.all(
        level.map(async (name) => {
          const file = resolve(dir, name)
          if (!file) return
          try {
            const text = await source.text(file)
            sources.set(dir + name, text)
            sources.set(name, text)
            for (const sf of sheetfiles(text)) {
              if (!seen.has(sf)) {
                seen.add(sf)
                pending.add(sf)
              }
            }
          } catch {
            // A missing sub-sheet: KiCanvas shows what it has.
          }
        }),
      )
    }

    // The .kicad_pro beside a schematic or board, or, when the project itself was picked, every schematic and board
    // in its folder, so KiCanvas has a root to open.
    const wanted = path.endsWith('.kicad_pro') ? /\.kicad_(sch|pcb)$/ : /\.kicad_pro$/
    const siblings = [...source.paths].filter(
      (p) => wanted.test(p) && p.startsWith(dir) && !p.slice(dir.length).includes('/') && !sources.has(p),
    )
    await Promise.all(
      siblings.map(async (p) => {
        try {
          const text = await source.text(p)
          sources.set(p, text)
          sources.set(p.slice(dir.length), text)
        } catch {
          // Optional.
        }
      }),
    )
    return sources
  }

  let mount: HTMLDivElement | undefined = $state()
  let status = $state<'loading' | 'ready' | 'error'>('loading')
  let error = $state<string | null>(null)

  $effect(() => {
    const theme = dark ? 'kicad' : 'witchhazel'
    let cancelled = false
    let embed: HTMLElement | null = null
    status = 'loading'
    Promise.all([loadKiCanvas(), collectSources()])
      .then(([, sources]) => {
        if (cancelled || !mount) return
        embed = document.createElement('kicanvas-embed')
        embed.setAttribute('controls', 'full')
        embed.setAttribute('controlslist', 'nooverlay')
        embed.setAttribute('theme', theme)
        embed.style.cssText = 'display:block;width:100%;height:100%'
        for (const [name, text] of sources) {
          const el = document.createElement('kicanvas-source')
          el.setAttribute('name', name)
          el.textContent = text
          embed.appendChild(el)
        }
        mount.replaceChildren(embed)
        status = 'ready'
      })
      .catch((e: Error) => {
        if (cancelled) return
        error = e.message
        status = 'error'
      })
    return () => {
      cancelled = true
      embed?.remove()
    }
  })
</script>

{#if status === 'error'}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t open this KiCad file ({error}).</p>
{:else}
  <div class="relative h-full">
    {#if status === 'loading'}
      <div class="absolute inset-0 z-10 bg-background"><Spinner label="Loading KiCanvas…" /></div>
    {/if}
    <div bind:this={mount} class="h-full"></div>
  </div>
{/if}
