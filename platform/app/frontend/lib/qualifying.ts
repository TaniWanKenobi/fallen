import type { ColumnDef } from '@tanstack/table-core'
import UserCell from '@/components/admin/UserCell.svelte'
import { renderComponent } from '@/components/admin/ui/data-table'
import { formatCount, formatDateTime, timeAgo } from '@/lib/format'
import { addDays } from '@/lib/streaks'
import type { AdminQualifyingRow } from '@/types'

// Shared by /admin/qualifying and its cards (components/admin/qualifying).

export type Status = AdminQualifyingRow['status']
// Counts by status at the end of a day (QualifyingPace.history).
// `close` is those behind who are just below the line; `reached` everyone with the final stage's XP, project or not;
// `bands` how many were in each of the spread's bands, in the same order.
export type Day = { date: string; close: number; reached: number; bands: number[] } & Record<Status, number>
// XP between two shares of the on-track line (QualifyingPace.spread); `from` null is no XP, `to` null the top band.
export type Band = { from: number | null; to: number | null; count: number }
export type Moves = { up: number; down: number }
// Everyone on a team, or only builders (people who have written a journal).
export type Group = 'all' | 'builders'
// Each team's on-track line and where just below it starts, at the end of yesterday (QualifyingPace.lines).
export type Lines = Record<string, { on_track: number; close: number }>

export const STATUSES: Record<Status, { label: string; color: string }> = {
  on_track: { label: 'On track', color: 'var(--chart-2)' },
  behind: { label: 'Behind', color: 'var(--chart-3)' },
  off_track: { label: 'Off track', color: 'var(--chart-5)' },
  qualified: { label: 'Qualified', color: 'var(--chart-4)' },
  not_started: { label: 'Not started', color: 'var(--muted-foreground)' },
}

// How far back the charts go and what the numbers are compared with, in days; null is since the race began.
export const RANGES: { value: string; label: string; days: number | null }[] = [
  { value: '7d', label: '7d', days: 7 },
  { value: '14d', label: '14d', days: 14 },
  { value: '30d', label: '30d', days: 30 },
  { value: 'all', label: 'All', days: null },
]
// The spread can also be compared with yesterday.
export const COMPARISONS = [{ value: '1d', label: 'Yesterday', days: 1 }, ...RANGES]
export const daysOf = (value: string) => COMPARISONS.find((option) => option.value === value)?.days ?? null

// The end of the day `days` before `today` in `timeline`, or its first day.
export const dayAgo = (timeline: Day[] | undefined, today: string, days: number | null) =>
  timeline?.find((day) => days !== null && day.date === addDays(today, -days)) ?? timeline?.[0]

export const share = (value: number) => `${Math.round(value * 100)}%`
export const percent = (part: number, whole: number | undefined) =>
  whole ? `${Math.round((part / whole) * 100)}%` : '–'
export const signed = (change: number) => `${change >= 0 ? '+' : '−'}${formatCount(Math.abs(change))}`
export const onTrack = (day: Pick<Day, 'qualified' | 'on_track'>) => day.qualified + day.on_track

const hours = (minutes: number) => `${formatCount(Math.round(minutes / 6) / 10)}h`

// The list's columns. `daysLeft` counts today.
export function qualifyingColumns({
  goalXp,
  daysLeft,
  lockInDays,
}: {
  goalXp: number
  daysLeft: number
  lockInDays: number
}) {
  // The hours someone has still to log to qualify, with their team's reward in full (QualifyingStats.hours_to_qualify).
  const hoursLeft = (row: AdminQualifyingRow) => Math.max(row.hours_to_qualify - row.total_minutes / 60, 0)

  const person: ColumnDef<AdminQualifyingRow> = {
    id: 'person',
    header: 'Person',
    cell: ({ row }) => renderComponent(UserCell, { user: row.original }),
  }
  const details: ColumnDef<AdminQualifyingRow>[] = [
    { accessorKey: 'xp', header: 'XP', cell: ({ row }) => formatCount(row.original.xp) },
    {
      id: 'line',
      header: 'vs. the line',
      cell: ({ row }) => `${signed(row.original.xp - row.original.line_xp)} XP`,
    },
    {
      id: 'projected',
      header: 'On pace for',
      cell: ({ row }) =>
        `${formatCount(row.original.projected_xp)} XP${row.original.projected_xp >= goalXp ? ' ✓' : ''}`,
    },
    {
      id: 'hours_to_qualify',
      header: 'Hours to qualify',
      // Their hours so far plus the rest with their team's reward in full, as the page's average counts it.
      cell: ({ row }) => {
        const left = hoursLeft(row.original)
        return `${formatCount(Math.round(row.original.hours_to_qualify))}h${left >= 0.5 ? ` (${formatCount(Math.round(left))}h to go)` : ''}`
      },
    },
    {
      id: 'needs',
      header: 'Hours needed a day',
      // The hours still to go spread over the days left, today included.
      cell: ({ row }) =>
        row.original.xp >= goalXp ? '–' : `${(hoursLeft(row.original) / Math.max(daysLeft, 1)).toFixed(1)}h`,
    },
    {
      id: 'recent',
      header: `Last ${lockInDays} days`,
      cell: ({ row }) => hours(row.original.recent_minutes),
    },
    {
      id: 'last_journal',
      header: 'Last journal',
      cell: ({ row }) => {
        const at = row.original.last_journal_at
        return at ? `${formatDateTime(at)} (${timeAgo(at)})` : 'Never'
      },
    },
  ]
  const status: ColumnDef<AdminQualifyingRow> = {
    id: 'status',
    header: 'Status',
    cell: ({ row }) => STATUSES[row.original.status].label,
  }
  const columns = [person, ...details]
  return {
    columns,
    lockingInColumns: [person, status, ...details],
    // For the skeletons while a table loads.
    headers: columns.map((column) => column.header as string),
  }
}
