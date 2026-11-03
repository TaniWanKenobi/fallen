import type { Person, ReviewJournal, ReviewSubmission, ReviewerNote } from '@/types'

// The review page's props (ReviewPageProps on the server).
export interface ReviewRepo {
  url: string
  host: string
  branch: string
  commit_sha: string
  paths: string[]
  truncated: boolean
  readme: string | null
  readme_path: string | null
  bom_path: string | null
  bom_csv: string | null
  file_url_prefix: string | null
}

export interface ReviewOptions {
  rubric: Record<string, string>
  answers: Answer[]
  journal_reasons: string[]
  cut_reasons: string[]
  adjust_reasons: string[]
}

export interface ReviewProject {
  id: string
  title: string
  description: string | null
  slack_url: string | null
  team: Person[]
  created_at: string
  logged_minutes: number
  journal_count: number
}

export interface ReviewPage {
  submission: ReviewSubmission
  project: ReviewProject
  journals: ReviewJournal[]
  repo: ReviewRepo | null
  history: ReviewSubmission[]
  notes: ReviewerNote[]
  options: ReviewOptions
  claimed: boolean
  can: { decide: boolean; reject: boolean; flag: boolean; unflag: boolean; note: boolean }
  skip: string
}

export type Answer = 'yes' | 'partly' | 'no'
export type Verdict = 'approved' | 'returned' | 'rejected'
export type ItemVerdict = 'approved' | 'adjusted' | 'cut'

export interface JournalCall {
  minutes: number | null
  reason: string | null
  note: string
  // Carried over from an earlier submission's review: shown, but the reviewer confirms it.
  carried: boolean
}

export interface ItemCall {
  verdict: ItemVerdict | null
  reason: string | null
  cents: number | null
}

export interface ReviewDraft {
  rubric: Record<string, Answer>
  journals: Record<string, JournalCall>
  bom: Record<string, ItemCall>
  feedback: string
  internal: string
}

const key = (id: string) => `fallen:review:${id}`

// The review's starting point: what was decided (a finished review), what the last review of each journal decided,
// or nothing yet. A half-done review comes back from the browser.
export function initialDraft(page: ReviewPage): ReviewDraft {
  const { submission, journals } = page
  const decided = submission.status !== 'pending'
  const fresh: ReviewDraft = {
    rubric: { ...submission.rubric },
    journals: Object.fromEntries(
      journals.map((j) => [
        j.id,
        j.earlier
          ? {
              minutes: j.earlier.approved_minutes,
              reason: j.earlier.reason,
              note: j.earlier.note ?? '',
              carried: !decided,
            }
          : { minutes: null, reason: null, note: '', carried: false },
      ]),
    ),
    bom: Object.fromEntries(
      submission.bom_items.map((item) => [
        item.id,
        { verdict: item.verdict, reason: item.reason, cents: item.approved_cents },
      ]),
    ),
    feedback: submission.feedback ?? '',
    internal: submission.internal_reason ?? '',
  }
  if (decided || typeof localStorage === 'undefined') return fresh
  try {
    const saved = JSON.parse(localStorage.getItem(key(submission.id)) ?? 'null') as ReviewDraft | null
    if (!saved) return fresh
    return {
      rubric: { ...fresh.rubric, ...saved.rubric },
      journals: Object.fromEntries(
        Object.entries(fresh.journals).map(([id, call]) => [id, saved.journals?.[id] ?? call]),
      ),
      bom: Object.fromEntries(Object.entries(fresh.bom).map(([id, call]) => [id, saved.bom?.[id] ?? call])),
      feedback: saved.feedback ?? '',
      internal: saved.internal ?? '',
    }
  } catch {
    return fresh
  }
}

export function saveReviewDraft(id: string, draft: ReviewDraft) {
  try {
    localStorage.setItem(key(id), JSON.stringify(draft))
  } catch {
    // Storage full or off: the review still works, it just isn't kept.
  }
}

export function clearReviewDraft(id: string) {
  localStorage.removeItem(key(id))
}

export const journalDecided = (call: JournalCall | undefined) =>
  call != null && call.minutes != null && !call.carried
export const journalDeflated = (journal: ReviewJournal, call: JournalCall | undefined) =>
  call?.minutes != null && call.minutes < (journal.duration_minutes ?? 0)

export function itemRequested(item: { owned: boolean; total_cents: number }) {
  return item.owned ? 0 : item.total_cents
}

export function itemFunded(item: { owned: boolean; total_cents: number }, call: ItemCall | undefined) {
  if (!call?.verdict) return null
  if (call.verdict === 'approved') return itemRequested(item)
  if (call.verdict === 'cut') return 0
  return Math.min(call.cents ?? 0, itemRequested(item))
}

// "1h 30m" / "90" / "1.5h" / "1:30" -> minutes, or null.
export function parseMinutes(text: string): number | null {
  const s = text.trim().toLowerCase()
  if (!s) return null
  const clock = s.match(/^(\d+):(\d{1,2})$/)
  if (clock) return Number(clock[1]) * 60 + Number(clock[2])
  const parts = s.match(/^(?:(\d+(?:\.\d+)?)\s*h(?:ours?|rs?)?)?\s*(?:(\d+)\s*m(?:in(?:utes?)?)?)?$/)
  if (parts && (parts[1] || parts[2])) return Math.round(Number(parts[1] ?? 0) * 60 + Number(parts[2] ?? 0))
  if (/^\d+(\.\d+)?$/.test(s)) return Math.round(Number(s) * 60)
  return null
}

// Feedback written from the review itself, so what the person reads matches what was decided.
export function draftFeedback(page: ReviewPage, draft: ReviewDraft): string {
  const lines: string[] = []
  const PHRASES: Record<string, Record<'partly' | 'no', string>> = {
    complete: { partly: 'The design isn’t quite finished yet.', no: 'The design isn’t finished yet.' },
    works: {
      partly: 'Some parts of the design might not work as drawn.',
      no: 'The design as it is wouldn’t work.',
    },
    original: {
      partly: 'Parts of it follow a guide closely. Make it more your own.',
      no: 'It looks copied rather than designed by you.',
    },
    documented: {
      partly: 'The README and repo are missing a few things someone would need to build it.',
      no: 'Someone couldn’t build it from the repo and README yet.',
    },
    journals: {
      partly: 'Some journals don’t show the work behind their hours.',
      no: 'The journals don’t show the work it took.',
    },
  }
  for (const [question, answer] of Object.entries(draft.rubric)) {
    if (answer === 'partly' || answer === 'no')
      lines.push(`- ${PHRASES[question]?.[answer] ?? page.options.rubric[question]}`)
  }
  const deflated = page.journals.filter((j) => journalDeflated(j, draft.journals[j.id]))
  if (deflated.length) {
    lines.push('', 'Journals:')
    for (const j of deflated) {
      const call = draft.journals[j.id]
      const date = new Date(j.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
      lines.push(
        `- ${date}: counted ${fmt(call.minutes ?? 0)} of ${fmt(j.duration_minutes ?? 0)} (${call.reason?.toLowerCase()})`,
      )
    }
  }
  const changed = page.submission.bom_items.filter((item) => {
    const call = draft.bom[item.id]
    return call?.verdict === 'cut' || call?.verdict === 'adjusted'
  })
  if (changed.length) {
    lines.push('', 'Parts list:')
    for (const item of changed) {
      const call = draft.bom[item.id]
      lines.push(
        `- ${item.name}: ${call.verdict === 'cut' ? 'cut' : 'lowered'} (${call.reason?.toLowerCase()})`,
      )
    }
  }
  return lines.join('\n').trim()
}

const fmt = (minutes: number) => {
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  return [h && `${h}h`, (m || !h) && `${m}m`].filter(Boolean).join(' ')
}

// Fallout's raised buttons, over the admin Button's classes: a soft top-down gradient, a drop shadow and a 1px
// highlight along the top.
export const RAISED = {
  success:
    'border-emerald-700 bg-linear-to-b from-emerald-500 to-emerald-600 text-white shadow-sm inset-shadow-2xs inset-shadow-emerald-300 hover:bg-transparent hover:from-emerald-400 dark:border-emerald-500 dark:inset-shadow-emerald-400',
  warning:
    'border-amber-300 bg-linear-to-b from-amber-50 to-amber-100 text-amber-800 shadow-xs inset-shadow-2xs inset-shadow-white hover:bg-transparent hover:to-amber-200 dark:border-amber-700 dark:from-amber-900 dark:to-amber-950 dark:text-amber-200 dark:inset-shadow-amber-800',
  primary:
    'border-zinc-950 bg-linear-to-b from-zinc-700 to-zinc-900 text-white shadow-sm inset-shadow-2xs inset-shadow-zinc-500 hover:bg-transparent hover:from-zinc-600 dark:border-zinc-300 dark:from-zinc-100 dark:to-zinc-300 dark:text-zinc-900 dark:inset-shadow-white',
}
// The key hints inside them, matched to each face.
export const RAISED_KEY = {
  success: 'border-emerald-400 bg-emerald-600 text-emerald-50',
  warning:
    'border-amber-300 bg-amber-100 text-amber-600 dark:border-amber-700 dark:bg-amber-900 dark:text-amber-400',
}
