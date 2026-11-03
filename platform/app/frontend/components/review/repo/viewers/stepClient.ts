import * as THREE from 'three'
import occtScriptUrl from 'occt-import-js/dist/occt-import-js.js?url'
import occtWasmUrl from 'occt-import-js/dist/occt-import-js.wasm?url'
import stepWorkerUrl from './stepWorker.ts?worker&url'
import { PART_MATERIAL } from './modelScene'

// STEP files are tessellated by OpenCascade (occt-import-js, about 7 MB of wasm) in one shared worker, set up the
// first time a STEP file is opened and reused after (Fallout's StepViewer).

let worker: Promise<Worker> | null = null
let nextId = 0
const pending = new Map<number, { resolve: (m: StepWorkerMesh[]) => void; reject: (e: Error) => void }>()

// In a build the worker is a plain classic script on our origin. Vite's dev server serves it as a module (with
// imports) and maybe from another origin, so in development its classic build is fetched, made import-free, its
// root-relative importScripts() calls pointed back at Vite, and it is started from a Blob.
async function createWorker(): Promise<Worker> {
  const url = new URL(stepWorkerUrl, import.meta.url)
  if (!import.meta.env.DEV) return new Worker(url)
  url.searchParams.set('type', 'classic')
  const source = await (await fetch(url)).text()
  const absolute = source
    .replace(/\bexport\s*\{\s*\};?/g, '')
    .replace(/importScripts\(\s*(["'])\//g, (_, q: string) => `importScripts(${q}${url.origin}/`)
  return new Worker(URL.createObjectURL(new Blob([absolute], { type: 'text/javascript' })))
}

function getWorker(): Promise<Worker> {
  if (worker) return worker
  worker = createWorker().then((w) => {
    w.onmessage = (e: MessageEvent<StepWorkerResponse>) => {
      const req = pending.get(e.data.id)
      if (!req) return
      pending.delete(e.data.id)
      if (e.data.ok) req.resolve(e.data.meshes)
      else req.reject(new Error(e.data.error))
    }
    w.onerror = (e) => {
      for (const req of pending.values()) req.reject(new Error(e.message || 'STEP worker crashed'))
      pending.clear()
      w.terminate()
      worker = null
    }
    // Absolute URLs: inside a Blob-started worker, relative ones would resolve against blob:.
    const init: StepWorkerRequest = {
      type: 'init',
      scriptUrl: new URL(occtScriptUrl, import.meta.url).href,
      wasmUrl: new URL(occtWasmUrl, import.meta.url).href,
    }
    w.postMessage(init)
    return w
  })
  worker.catch(() => (worker = null))
  return worker
}

export async function parseStep(buffer: ArrayBuffer): Promise<StepWorkerMesh[]> {
  const w = await getWorker()
  const id = nextId++
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject })
    const req: StepWorkerRequest = { type: 'parse', id, buffer }
    w.postMessage(req, [buffer])
  })
}

export function buildGroup(meshes: StepWorkerMesh[]): THREE.Group {
  const group = new THREE.Group()
  for (const m of meshes) {
    const geometry = new THREE.BufferGeometry()
    geometry.setAttribute('position', new THREE.BufferAttribute(m.position, 3))
    if (m.normal) geometry.setAttribute('normal', new THREE.BufferAttribute(m.normal, 3))
    else geometry.computeVertexNormals()
    if (m.index) geometry.setIndex(new THREE.BufferAttribute(m.index, 1))
    const material = m.color ? PART_MATERIAL.clone() : PART_MATERIAL
    if (m.color) material.color = new THREE.Color(m.color[0], m.color[1], m.color[2])
    const mesh = new THREE.Mesh(geometry, material)
    mesh.name = m.name
    group.add(mesh)
  }
  return group
}
