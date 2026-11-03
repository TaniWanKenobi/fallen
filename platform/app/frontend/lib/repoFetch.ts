import DOMPurify from 'dompurify'
import { csrfToken } from '@/lib/csrf'
import { reviewSubmissionRepoFiles } from '@/routes'

// Files of a submission's repository for the review page's viewers. Repos can be on any git host, so the browser
// never fetches them itself: it asks our server (Review::RepoFilesController), which reads the file at the
// submitted commit in a job, and asks again until it's ready.

const LFS_POINTER = 'version https://git-lfs.github.com/spec'
const GIVE_UP_AFTER_MS = 180_000

export interface RepoSource {
  paths: Set<string>
  buffer(path: string): Promise<ArrayBuffer>
  text(path: string): Promise<string>
  // An object URL for <img> and loaders that want one. Lives as long as the page.
  objectUrl(path: string): Promise<string>
  // Bytes, once a file has been fetched, so the header can show its size.
  size(path: string): number | null
  onSize(listener: () => void): () => void
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

export function createRepoSource(submissionId: string, paths: string[]): RepoSource {
  const buffers = new Map<string, Promise<ArrayBuffer>>()
  const urls = new Map<string, Promise<string>>()
  const sizes = new Map<string, number>()
  const listeners = new Set<() => void>()

  async function locate(path: string): Promise<string> {
    const started = Date.now()
    for (let attempt = 0; ; attempt++) {
      const response = await fetch(reviewSubmissionRepoFiles(submissionId).url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'X-CSRF-Token': csrfToken(),
        },
        credentials: 'same-origin',
        body: JSON.stringify({ path }),
      })
      if (response.status === 404) throw new Error('not in this repository')
      if (!response.ok) throw new Error(`${response.status} ${response.statusText}`)
      const data = (await response.json()) as { status: string; url?: string; size?: number; error?: string }
      if (data.status === 'done' && data.url) {
        if (data.size != null) {
          sizes.set(path, data.size)
          listeners.forEach((listener) => listener())
        }
        return data.url
      }
      if (data.status === 'failed') throw new Error(data.error || 'it could not be read')
      if (Date.now() - started > GIVE_UP_AFTER_MS) throw new Error('it is taking too long to read')
      await sleep(Math.min(3000, 700 + attempt * 300))
    }
  }

  function buffer(path: string): Promise<ArrayBuffer> {
    let promise = buffers.get(path)
    if (!promise) {
      promise = locate(path).then(async (url) => {
        const response = await fetch(url, { credentials: 'same-origin' })
        if (!response.ok) throw new Error(`${response.status} ${response.statusText}`)
        return response.arrayBuffer()
      })
      buffers.set(path, promise)
      promise.catch(() => buffers.delete(path))
    }
    return promise
  }

  return {
    paths: new Set(paths),
    buffer,
    text: async (path) => new TextDecoder().decode(await buffer(path)),
    objectUrl(path) {
      let promise = urls.get(path)
      if (!promise) {
        promise = buffer(path).then((bytes) => {
          const type = imageType(path)
          // A blob: URL is our origin, and an SVG opened from one in its own tab would run its scripts.
          const body =
            type === 'image/svg+xml'
              ? DOMPurify.sanitize(new TextDecoder().decode(bytes), {
                  USE_PROFILES: { svg: true, svgFilters: true },
                })
              : bytes
          return URL.createObjectURL(new Blob([body], { type }))
        })
        urls.set(path, promise)
        promise.catch(() => urls.delete(path))
      }
      return promise
    },
    size: (path) => sizes.get(path) ?? null,
    onSize(listener) {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },
  }
}

function imageType(path: string): string {
  const ext = path.split('.').pop()?.toLowerCase() ?? ''
  const types: Record<string, string> = {
    png: 'image/png',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    gif: 'image/gif',
    webp: 'image/webp',
    bmp: 'image/bmp',
    ico: 'image/x-icon',
    avif: 'image/avif',
    svg: 'image/svg+xml',
  }
  return types[ext] ?? 'application/octet-stream'
}

export function isLfsPointer(text: string): boolean {
  return text.startsWith(LFS_POINTER)
}

export function looksBinary(text: string): boolean {
  return text.includes('\u0000')
}
