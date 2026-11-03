import DOMPurify from 'dompurify'
import { marked } from 'marked'

// Markdown from a submitted repository, shown in our origin, so it goes through the same allowlist GitHub uses for
// READMEs (hast-util-sanitize's default schema, as Fallout uses): raw HTML like <img width> and <details> stays,
// anything that runs or styles does not. Pictures never load from other hosts. One that is a file of the repo (a
// relative path, or a link to the same repo on its host) gets `data-repo-src` for the viewer to fill from our file
// endpoint; any other becomes a link. Links to files of the repo get `data-repo-path`, so the viewer can open them.

const ALLOWED_TAGS = (
  'a b blockquote br code dd del details div dl dt em h1 h2 h3 h4 h5 h6 hr i img input ins kbd li ol p picture pre ' +
  'q rp rt ruby s samp section source span strike strong sub summary sup table tbody td tfoot th thead tr tt ul var'
).split(' ')
const ALLOWED_ATTR = (
  'href src alt title width height align start type checked disabled colspan rowspan open abbr cite datetime ' +
  'dir lang summary valign'
).split(' ')

export interface RepoLinks {
  // Repo-relative paths of every file in the snapshot.
  paths: Set<string>
  // The directory the Markdown file is in, '' at the root.
  dir: string
  // The repository's own URL (https://host/owner/name).
  repoUrl: string
  // A link to a file on the repo's host, when we know its URL scheme.
  fileUrl: (path: string) => string | null
}

const BASE = 'https://repo.invalid/'

// A relative URL in the Markdown as a path in the repo (file or not), or null for anything else.
function relativePath(url: string, dir: string): string | null {
  if (!url || url.startsWith('#') || /^[a-z][a-z0-9+.-]*:|^\/\//i.test(url)) return null
  try {
    const resolved = new URL(url, BASE + dir)
    if (resolved.origin !== new URL(BASE).origin) return null
    return decodeURIComponent(resolved.pathname.slice(1))
  } catch {
    return null
  }
}

// A URL in the Markdown as a file of the repo, or null.
export function repoPath(url: string, links: RepoLinks): string | null {
  const relative = relativePath(url, links.dir)
  if (relative !== null) return links.paths.has(relative) ? relative : null
  return /^https?:\/\//i.test(url) ? sameRepoPath(url, links) : null
}

// Absolute links back into the same repository (".../blob/main/img/x.png", raw.githubusercontent.com/...): the path
// is whatever tail of the URL is a file in the snapshot, whatever ref it names.
function sameRepoPath(url: string, links: RepoLinks): string | null {
  let parsed: URL
  let repo: URL
  try {
    parsed = new URL(url)
    repo = new URL(links.repoUrl)
  } catch {
    return null
  }
  const repoParts = repo.pathname
    .replace(/\.git$/, '')
    .split('/')
    .filter(Boolean)
  const parts = parsed.pathname.split('/').filter(Boolean).map(decodeURIComponent)
  const sameHost = parsed.host === repo.host
  const rawGithub = repo.host === 'github.com' && parsed.host === 'raw.githubusercontent.com'
  if (!sameHost && !rawGithub) return null
  const head = parts.slice(0, repoParts.length).map((p) => p.toLowerCase())
  if (head.join('/') !== repoParts.map((p) => p.toLowerCase()).join('/')) return null
  const rest = parts.slice(repoParts.length)
  for (let i = 0; i < rest.length; i++) {
    const candidate = rest.slice(i).join('/')
    if (links.paths.has(candidate)) return candidate
  }
  return null
}

export function renderRepoMarkdown(markdown: string, links: RepoLinks): string {
  const html = marked.parse(markdown, { async: false, gfm: true, breaks: false }) as string
  const fragment = DOMPurify.sanitize(html, { ALLOWED_TAGS, ALLOWED_ATTR, RETURN_DOM_FRAGMENT: true })
  // <picture> falls back to its <img>, so its other sources (which could be anywhere) are dropped.
  for (const source of fragment.querySelectorAll('source')) source.remove()
  for (const img of fragment.querySelectorAll('img')) {
    const src = img.getAttribute('src') ?? ''
    const path = repoPath(src, links)
    img.removeAttribute('src')
    if (path) {
      img.setAttribute('data-repo-src', path)
      continue
    }
    const link = document.createElement('a')
    if (/^https?:\/\//i.test(src)) {
      link.setAttribute('href', src)
      link.setAttribute('target', '_blank')
      link.setAttribute('rel', 'noopener noreferrer')
    }
    const alt = img.getAttribute('alt')
    link.textContent = `[image${alt ? `: ${alt}` : ''}]`
    img.replaceWith(link)
  }
  for (const a of fragment.querySelectorAll('a')) {
    const href = a.getAttribute('href') ?? ''
    if (href.startsWith('#')) continue
    const path = repoPath(href, links)
    if (path) {
      a.setAttribute('data-repo-path', path)
      a.setAttribute('href', links.fileUrl(path) ?? '#')
    } else if (/^https?:\/\//i.test(href)) {
      a.setAttribute('target', '_blank')
      a.setAttribute('rel', 'noopener noreferrer')
    } else {
      const relative = relativePath(href, links.dir)
      const url = relative !== null ? links.fileUrl(relative.replace(/\/$/, '')) : null
      if (url) {
        a.setAttribute('href', url)
        a.setAttribute('target', '_blank')
        a.setAttribute('rel', 'noopener noreferrer')
      } else a.removeAttribute('href')
    }
  }
  const container = document.createElement('div')
  container.append(fragment)
  return container.innerHTML
}
