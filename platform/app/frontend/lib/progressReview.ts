import type { Person, ProgressReviewRow, ReviewJournal, ReviewTodo, ReviewerNote } from '@/types'

// The journal review page's props (ProgressPageProps on the server).
export interface ProgressPage {
  project: {
    id: string
    title: string
    description: string | null
    slack_url: string | null
    team: Person[]
    created_at: string
    submitted: boolean
  }
  status: {
    due_reason: 'requested' | 'added' | 'first' | 'approved' | 'check_back' | 'submitted' | null
    due_label: string | null
    due_since: string | null
    logged_minutes: number
    approvals_count: number
    reviews_count: number
    // The logged time that brings it back after an approval; null while it waits on a journal instead.
    next_due_minutes: number | null
    // How much more logged time approving now would wait for.
    next_gap_minutes: number
    waiting_since: string | null
    last_reviewed_at: string | null
    flagged_at: string | null
    flag_reason: string | null
    flagged_by: Person | null
    starred: boolean
    starred_by: Person | null
    claimed_by: Person | null
    claim_expires_at: string | null
    // What the team asked to have looked at, when they asked for this review themselves.
    request: { at: string; note: string | null; by: Person | null } | null
    // The admin who put it in the queue by hand, when that's why it's here.
    added: { at: string; by: Person | null } | null
  }
  journals: ReviewJournal[]
  history: ProgressReviewRow[]
  notes: ReviewerNote[]
  // Every check, by key; only `required_checks` block an approval, the rest are noted for reviewers.
  checks: Record<string, string>
  required_checks: string[]
  max_journal_note: number
  // Links the reviewer can drop into their feedback (ProgressReview::RESOURCES).
  resources: { label: string; url: string }[]
  // What earlier check backs asked to fix and the team hasn't had resolved yet, ticked or not.
  todos: ReviewTodo[]
  // XP held back from the team until a reviewer sees the fixes; approving gives it back.
  held_xp: number
  // How much of the XP since the last review a check back holds (ProgressReview::XP_HELD_SHARE).
  xp_held_share: number
  // Whether a check back now holds XP (the last review was a check back too) rather than only warning.
  check_back_holds: boolean
  max_todo: number
  claimed: boolean
  // `own`: the reviewer is on the project's team, so someone else has to review it.
  can: {
    decide: boolean
    take_over: boolean
    flag: boolean
    unflag: boolean
    star: boolean
    dismiss: boolean
    own: boolean
  }
  skip: string
  // Deferred: each teammate's record outside this project (ProgressPageProps.people).
  people?: PersonRecord[]
}

export interface PersonRecord {
  person: Person
  joined_at: string
  other_projects: number
  approved: number
  check_backs: number
}

export type ProgressVerdict = 'approved' | 'check_back' | 'dismissed'

// A note an earlier review left on one journal, shown on that journal's card.
export interface EarlierNote {
  id: string
  note: string
  at: string
  verdict: ProgressVerdict
  reviewer: Person | null
}
