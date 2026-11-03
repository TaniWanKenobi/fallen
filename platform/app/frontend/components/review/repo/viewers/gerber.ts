import { createParser } from '@tracespace/parser'
import { plot } from '@tracespace/plotter'
import { render } from '@tracespace/renderer'
import { toHtml } from 'hast-util-to-html'
import whatsThatGerber, { type GerberLayerInfo } from 'whats-that-gerber'
import { listZipEntries } from '@/lib/unzip'

// Gerber and drill files (one, or every one in a fab zip) plotted to SVG with tracespace, one layer each, coloured
// by what whats-that-gerber says the layer is and stacked on one shared viewBox (Fallout's GerberViewer).

const GERBER_RE = /\.(gbr|ger|gtl|gbl|gts|gbs|gto|gbo|gtp|gbp|gm1|gm2|gko|drl|xln)$/i

export type Tone = 'copper' | 'mask' | 'silkscreen' | 'paste' | 'drill' | 'outline' | 'other'
export const TONE_COLOR: Record<Tone, string> = {
  copper: '#f0a030',
  mask: '#2fbf71',
  silkscreen: '#f4f4f5',
  paste: '#a6c8ff',
  drill: '#67e8f9',
  outline: '#fde047',
  other: '#a1a1aa',
}
// Bottom-to-top paint order so copper reads under silkscreen and drills punch through.
const TONE_ORDER: Tone[] = ['outline', 'copper', 'mask', 'paste', 'silkscreen', 'drill', 'other']

export interface Layer {
  name: string
  svg: string
  tone: Tone
  label: string
  visible: boolean
}

function toneFor(info: GerberLayerInfo | undefined, name: string): Tone {
  const type = (info?.type ?? '').toLowerCase()
  if (type in TONE_COLOR) return type as Tone
  const lower = name.toLowerCase()
  if (/edge|outline|cuts|gko|gm1/.test(lower)) return 'outline'
  if (/\.(drl|xln)$/.test(lower)) return 'drill'
  return 'other'
}

function labelFor(info: GerberLayerInfo | undefined, name: string): string {
  if (!info?.type && !info?.side) return name
  const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)
  return [info.side && cap(info.side), info.type && cap(info.type)].filter(Boolean).join(' ')
}

type ViewBox = [number, number, number, number]

function parseViewBox(svg: string): ViewBox | null {
  const m = svg.match(/\bviewBox="([^"]+)"/i)
  const parts = m?.[1].trim().split(/\s+/).map(Number)
  return parts && parts.length === 4 && parts.every(Number.isFinite) ? (parts as ViewBox) : null
}

function renderSvg(text: string): string {
  const parser = createParser()
  parser.feed(text)
  // tracespace v5 alpha ships loose typings between packages; the trees are compatible at runtime.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const image = plot(parser.results() as any)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return toHtml(render(image) as any, { space: 'svg' })
}

function normalize(svg: string, color: string, box: ViewBox | null): string {
  let out = svg.replace(/<rect\b[^>]*\bfill="black"[^>]*>\s*<\/rect>/gi, '')
  if (box) out = out.replace(/\bviewBox="[^"]*"/i, `viewBox="${box.join(' ')}"`)
  // Whitespace before the name, so the stroke-width on the same tag isn't the one replaced.
  out = out.replace(/\swidth="[^"]*"/i, ' width="100%"').replace(/\sheight="[^"]*"/i, ' height="100%"')
  if (!/preserveAspectRatio=/i.test(out))
    out = out.replace(/<svg\b/i, '<svg preserveAspectRatio="xMidYMid meet"')
  return out.replace(/\b(fill|stroke)="(black|currentColor)"/gi, `$1="${color}"`)
}

export async function loadLayers(buffer: ArrayBuffer, name: string, zip: boolean): Promise<Layer[]> {
  const files: { name: string; text: string }[] = []
  if (zip) {
    for (const entry of listZipEntries(buffer)) {
      // macOS zips carry a ._ resource-fork copy of every file, which isn't a Gerber.
      if (!GERBER_RE.test(entry.name) || /(^|\/)(__MACOSX\/|\._)/.test(entry.name)) continue
      files.push({ name: entry.name.split('/').pop()!, text: new TextDecoder().decode(await entry.read()) })
    }
    if (files.length === 0) throw new Error('No Gerber files found in this archive')
  } else {
    files.push({ name, text: new TextDecoder().decode(buffer) })
  }

  const info = whatsThatGerber(files.map((f) => f.name))
  const rendered: { name: string; svg: string; tone: Tone; label: string }[] = []
  for (const f of files) {
    try {
      rendered.push({
        name: f.name,
        svg: renderSvg(f.text),
        tone: toneFor(info[f.name], f.name),
        label: labelFor(info[f.name], f.name),
      })
    } catch {
      // An unparseable layer (a job file, say) is skipped rather than failing the whole board
    }
  }
  if (rendered.length === 0) throw new Error('None of the Gerber layers could be parsed')

  const boxes = rendered.map((l) => parseViewBox(l.svg)).filter((b): b is ViewBox => !!b)
  const merged: ViewBox | null = boxes.length
    ? (() => {
        const minX = Math.min(...boxes.map((b) => b[0]))
        const minY = Math.min(...boxes.map((b) => b[1]))
        const maxX = Math.max(...boxes.map((b) => b[0] + b[2]))
        const maxY = Math.max(...boxes.map((b) => b[1] + b[3]))
        return [minX, minY, maxX - minX, maxY - minY]
      })()
    : null

  return rendered
    .sort((a, b) => TONE_ORDER.indexOf(a.tone) - TONE_ORDER.indexOf(b.tone) || a.name.localeCompare(b.name))
    .map((l) => ({ ...l, svg: normalize(l.svg, TONE_COLOR[l.tone], merged), visible: true }))
}
