import { fileExt } from '@/lib/repoFileKinds'
import {
  analyzeEasyEdaJson,
  extractPrimaryEasyEdaArchiveJsonDocument,
  inspectEasyEdaArchive,
  tryParseJsonContent,
  type EasyEdaArchiveInspection,
  type EasyEdaDocumentKind,
} from './easyeda/easyeda'
import { buildEasyEdaVisualDocument, type EasyEdaVisualDocument } from './easyeda/easyedaVisual'
import {
  buildEasyEdaProPcbVisual,
  buildEasyEdaProSchematicVisual,
  extractEasyEdaProArchive,
  parseProDocument,
  type ProArchive,
} from './easyeda/easyedaPro'

// EasyEDA files (Pro projects and documents, classic JSON exports, zips of either) read into drawable sheets, from
// Fallout's EasyEdaViewer, whose parsers are vendored from hackclub/hardware-unified-review-tool.

export interface Sheet {
  id: string
  label: string
  kind: EasyEdaDocumentKind
  build: () => EasyEdaVisualDocument | null
}

export type Result =
  | { mode: 'sheets'; sheets: Sheet[]; defaultIndex: number }
  | { mode: 'json'; kind: EasyEdaDocumentKind; visual: EasyEdaVisualDocument | null; preview: string }
  | { mode: 'archive'; inspection: EasyEdaArchiveInspection }

const PREVIEW_LIMIT = 18_000

function emptyArchive(): ProArchive {
  return {
    projectInfo: null,
    pcbs: new Map(),
    schematicSheets: new Map(),
    footprints: new Map(),
    symbols: new Map(),
  }
}

function sheetsFromArchive(archive: ProArchive): Sheet[] {
  const sheets: Sheet[] = []
  for (const [id, doc] of archive.pcbs) {
    const label = archive.projectInfo?.pcbs.find((p) => p.uuid === id)?.name ?? id
    sheets.push({
      id: `pcb:${id}`,
      label: `PCB · ${label}`,
      kind: 'pcb',
      build: () => buildEasyEdaProPcbVisual(archive, doc, label),
    })
  }
  const ordered: string[] = []
  for (const sch of archive.projectInfo?.schematics ?? []) {
    for (const sheet of sch.sheets) {
      const key = `${sch.uuid}/${sheet.id}`
      if (archive.schematicSheets.has(key)) ordered.push(key)
    }
  }
  for (const key of archive.schematicSheets.keys()) if (!ordered.includes(key)) ordered.push(key)
  for (const key of ordered) {
    const doc = archive.schematicSheets.get(key)!
    const [schUuid, sheetId] = key.split('/')
    const sch = archive.projectInfo?.schematics.find((s) => s.uuid === schUuid)
    const name = sch?.sheets.find((s) => String(s.id) === sheetId || s.uuid === sheetId)?.name ?? key
    sheets.push({
      id: `sch:${key}`,
      label: `Schematic · ${name}`,
      kind: 'schematic',
      build: () => buildEasyEdaProSchematicVisual(archive, doc, name),
    })
  }
  return sheets
}

function jsonResult(value: unknown, name: string, text?: string): Result {
  const inspection = analyzeEasyEdaJson(value, name)
  const source = text ?? JSON.stringify(value, null, 2)
  const preview = source.length > PREVIEW_LIMIT ? `${source.slice(0, PREVIEW_LIMIT)}\n…` : source
  return {
    mode: 'json',
    kind: inspection.documentKind,
    visual: buildEasyEdaVisualDocument(value, name, inspection.documentKind),
    preview,
  }
}

export async function readEasyEda(content: ArrayBuffer, name: string): Promise<Result> {
  const ext = fileExt(name)

  if (ext === 'epro' || ext === 'eproproject') {
    try {
      const sheets = sheetsFromArchive(await extractEasyEdaProArchive(content))
      if (sheets.length > 0)
        return {
          mode: 'sheets',
          sheets,
          defaultIndex: Math.max(
            0,
            sheets.findIndex((s) => s.kind === 'pcb'),
          ),
        }
    } catch {
      // Not a Pro archive: fall through to the legacy JSON paths
    }
  }

  const parsed = tryParseJsonContent(content)
  if (ext === 'esch' || ext === 'epcb') {
    if (!parsed) {
      const doc = parseProDocument(new TextDecoder().decode(content))
      if (!doc) throw new Error('Not a readable EasyEDA Pro document')
      const archive = emptyArchive()
      const isPcb = ext === 'epcb' || /^pcb$/i.test(doc.docType)
      const sheet: Sheet = isPcb
        ? { id: 'pcb', label: name, kind: 'pcb', build: () => buildEasyEdaProPcbVisual(archive, doc, name) }
        : {
            id: 'sch',
            label: name,
            kind: 'schematic',
            build: () => buildEasyEdaProSchematicVisual(archive, doc, name),
          }
      return { mode: 'sheets', sheets: [sheet], defaultIndex: 0 }
    }
    return jsonResult(parsed.value, name, parsed.text)
  }
  if (parsed) return jsonResult(parsed.value, name, parsed.text)

  const doc = await extractPrimaryEasyEdaArchiveJsonDocument(content)
  if (doc) return jsonResult(doc.value, doc.name, doc.text)
  return { mode: 'archive', inspection: await inspectEasyEdaArchive(content) }
}
