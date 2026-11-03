import { DirectUpload, type Blob } from '@rails/activestorage'
import { csrfToken } from '@/lib/csrf'
import { photoChecks } from '@/routes'

export interface UploadedImage {
  id: string
  url: string
  filename: string
}

export const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp']
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024

// The image in a paste meant for the page as a whole, like a banner: not one going into a text box, an editor or a
// dialog (the journal composer), which takes its own.
export function pastedPageImage(event: ClipboardEvent): File | undefined {
  const target = event.target instanceof Element ? event.target : null
  if (
    event.defaultPrevented ||
    target?.closest('input, textarea, [contenteditable], dialog, [role="dialog"]')
  )
    return
  return [...(event.clipboardData?.files ?? [])].find((f) => IMAGE_TYPES.includes(f.type))
}

// DirectUpload reads the token from the <meta> tag, which Inertia never re-renders.
function refreshCsrfMeta() {
  const meta = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
  if (meta) meta.content = csrfToken()
}

function directUpload(file: File, uploadUrl: string, onProgress?: (fraction: number) => void): Promise<Blob> {
  return new Promise((resolve, reject) => {
    new DirectUpload(file, uploadUrl, {
      directUploadWillStoreFileWithXHR: (xhr) =>
        xhr.upload.addEventListener(
          'progress',
          (e) => e.lengthComputable && onProgress?.(e.loaded / e.total),
        ),
    }).create((error, blob) => (error ? reject(error) : resolve(blob)))
  })
}

// PUTs the file straight to storage, then asks UploadsController to check its bytes, which is what hands out the
// blob's signed id. The URL is Active Storage's own redirect route, not one of ours.
export async function uploadImage(
  file: File,
  uploadUrl: string,
  onProgress?: (fraction: number) => void,
): Promise<UploadedImage> {
  if (!IMAGE_TYPES.includes(file.type)) throw new Error(`${file.name} is not a PNG, JPEG, GIF or WebP`)
  if (file.size > MAX_IMAGE_BYTES) throw new Error(`${file.name} is over 10 MB`)

  refreshCsrfMeta()
  const { finish_url } = await directUpload(file, uploadUrl, onProgress).catch(() => {
    throw new Error(`Couldn't upload ${file.name}`)
  })
  const response = await fetch(finish_url, {
    method: 'PATCH',
    headers: { 'X-CSRF-Token': csrfToken(), Accept: 'application/json' },
    credentials: 'same-origin',
  })
  const data = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(data.error ?? `Couldn't upload ${file.name} (${response.status})`)

  return {
    id: data.signed_id,
    url: `/rails/active_storage/blobs/redirect/${data.signed_id}/${encodeURIComponent(data.filename)}`,
    filename: data.filename,
  }
}

// PhotoChecksController: which of these photos can't go on the journal any more, because another journal has them.
// Not knowing (offline, an error) counts as none, and the save says what's wrong instead.
export async function takenPhotos(ids: string[], journalId?: string): Promise<string[]> {
  if (ids.length === 0) return []
  try {
    const response = await fetch(photoChecks.create().url, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken(),
      },
      body: JSON.stringify({ ids, journal: journalId }),
    })
    if (!response.ok) return []
    const data = await response.json()
    return Array.isArray(data.taken) ? data.taken : []
  } catch {
    return []
  }
}

// The writing without the photos `ids` (Markdown images whose URL holds the signed id).
export function withoutPhotos(markdown: string, ids: string[]): string {
  const escaped = ids.map((id) => id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|')
  return markdown
    .replace(new RegExp(`!\\[[^\\]]*\\]\\([^)]*(?:${escaped})[^)]*\\)`, 'g'), '')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}
