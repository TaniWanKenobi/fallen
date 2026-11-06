// The transfer Lapse review (TransferLapseReview on the server, which this mirrors to show totals as you edit).
import type { AdminTransferLapse } from '@/types'

export type Recording = NonNullable<AdminTransferLapse['recordings']>[number]
export type Note = AdminTransferLapse['lapse_annotations'][string]
export type Segment = NonNullable<Note['segments']>[number]
export type SegmentType = Segment['type']

// TransferLapseReview::REAL_SECONDS_PER_VIDEO_SECOND: what a video second stands for until the video says.
export const REAL_SECONDS_PER_VIDEO_SECOND = 60

export const REASONS: Record<SegmentType, string[]> = {
  removed: ['AFK / idle screen', 'Not this project', 'Duplicate recording', 'Unrelated browsing', 'Other'],
  deflated: ['Tutorial watching', 'Slow progress / distracted', 'Partly off-topic', 'Other'],
}

export function scaleOf(recording: Recording, note: Note | undefined) {
  const video = note?.video_seconds ?? 0
  return video > 0 ? recording.seconds / video : REAL_SECONDS_PER_VIDEO_SECOND
}

// The video's length in seconds, measured or estimated.
export function videoLength(recording: Recording, note: Note | undefined) {
  return note?.video_seconds ?? recording.seconds / REAL_SECONDS_PER_VIDEO_SECOND
}

export function cutSeconds(segment: Segment, scale: number) {
  const length = (segment.end - segment.start) * scale
  return segment.type === 'removed' ? length : (length * (segment.percent ?? 0)) / 100
}

export function approvedSeconds(recording: Recording, note: Note | undefined) {
  const scale = scaleOf(recording, note)
  const cut = (note?.segments ?? []).reduce((sum, segment) => sum + cutSeconds(segment, scale), 0)
  return Math.min(Math.max(Math.round(recording.seconds - cut), 0), recording.seconds)
}

// A video position as m:ss.
export function timestamp(seconds: number) {
  const whole = Math.max(Math.round(seconds), 0)
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, '0')}`
}

export const overlaps = (segments: Segment[], start: number, end: number) =>
  segments.some((segment) => start < segment.end && segment.start < end)
