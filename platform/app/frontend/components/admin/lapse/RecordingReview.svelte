<script lang="ts">
  // One Lapse or Lookout recording: the video, its timeline and the stretches the reviewer cut from it.
  import ExternalLink from '@lucide/svelte/icons/external-link'
  import Gauge from '@lucide/svelte/icons/gauge'
  import MinusCircle from '@lucide/svelte/icons/circle-minus'
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert'
  import Trash from '@lucide/svelte/icons/trash-2'
  import LapseTimeline from '@/components/admin/lapse/LapseTimeline.svelte'
  import SegmentForm from '@/components/admin/lapse/SegmentForm.svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { Textarea } from '@/components/admin/ui/textarea'
  import { formatDateTime, formatSeconds } from '@/lib/format'
  import {
    approvedSeconds,
    cutSeconds,
    scaleOf,
    timestamp,
    videoLength,
    type Note,
    type Recording,
    type SegmentType,
  } from '@/lib/lapseReview'

  const RATES = [1, 2, 4, 8]

  let {
    recording,
    note,
    hackatimeUserId,
    slackId,
    editable,
    onchange,
  }: {
    recording: Recording
    note: Note | undefined
    hackatimeUserId: string | null
    slackId: string | null
    editable: boolean
    onchange: (note: Note) => void
  } = $props()

  let video: HTMLVideoElement | undefined = $state()
  let currentTime = $state(0)
  let rate = $state(2)
  let adding: SegmentType | null = $state(null)
  let preview: { start: number; end: number; type: SegmentType } | null = $state(null)

  const segments = $derived(note?.segments ?? [])
  const scale = $derived(scaleOf(recording, note))
  const length = $derived(videoLength(recording, note))
  const approved = $derived(approvedSeconds(recording, note))
  const warnings = $derived(
    [
      recording.missing &&
        `${recording.kind === 'lapse' ? 'Lapse' : 'Lookout'} no longer shows this recording; only its heartbeats are left.`,
      recording.owner_hackatime_id &&
        hackatimeUserId &&
        recording.owner_hackatime_id !== hackatimeUserId &&
        `Lapse says Hackatime user ${recording.owner_hackatime_id} recorded this, not ${hackatimeUserId}.`,
      recording.owner_slack_id &&
        slackId &&
        recording.owner_slack_id !== slackId &&
        `Recorded by Slack account ${recording.owner_slack_id}, not this person's (${slackId}).`,
      recording.status &&
        recording.status !== 'complete' &&
        `Lookout says this session is ${recording.status}.`,
      ...recording.counted.map((where) => `Also counted in ${where}.`),
    ].filter((warning): warning is string => !!warning),
  )

  const update = (changes: Partial<Note>) => onchange({ ...note, ...changes })

  function measured() {
    const seconds = video?.duration
    if (seconds && Number.isFinite(seconds) && Math.abs((note?.video_seconds ?? 0) - seconds) > 0.5)
      update({ video_seconds: Math.round(seconds * 100) / 100 })
    if (video) video.playbackRate = rate
  }

  function seek(seconds: number) {
    currentTime = seconds
    if (video) video.currentTime = seconds
  }
</script>

<Card.Root size="sm" class={note?.reviewed ? 'border-emerald-500/40' : ''}>
  <Card.Header>
    <div class="flex flex-wrap items-center gap-2">
      <Card.Title class="text-base">{recording.name || 'Untitled recording'}</Card.Title>
      <Badge variant="secondary">{recording.kind === 'lapse' ? 'Lapse' : 'Lookout'}</Badge>
      {#if recording.visibility && recording.visibility !== 'PUBLIC'}<Badge variant="outline"
          >{recording.visibility.toLowerCase()}</Badge
        >{/if}
      {#if note?.reviewed}<Badge>Reviewed</Badge>{/if}
      {#if recording.url}
        <a
          href={recording.url}
          target="_blank"
          rel="noreferrer"
          class="ml-auto inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
          >On Lapse <ExternalLink class="size-3" /></a
        >
      {/if}
    </div>
    <Card.Description>
      {recording.started_at ? formatDateTime(recording.started_at) : 'Unknown start'} · Hackatime project “{recording.project}”
      · {recording.heartbeats}
      {recording.heartbeats === 1 ? 'heartbeat' : 'heartbeats'}
    </Card.Description>
  </Card.Header>
  <Card.Content class="space-y-3">
    {#each warnings as warning (warning)}
      <p class="flex gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-2 text-sm">
        <TriangleAlert class="size-4 shrink-0 text-destructive" />{warning}
      </p>
    {/each}

    {#if recording.playback_url}
      <!-- svelte-ignore a11y_media_has_caption -->
      <video
        bind:this={video}
        bind:currentTime
        src={recording.playback_url}
        poster={recording.thumbnail_url ?? undefined}
        preload="metadata"
        controls
        class="aspect-video w-full rounded-md bg-black"
        onloadedmetadata={measured}
      ></video>
      <div class="flex flex-wrap items-center gap-1 text-xs text-muted-foreground">
        Speed
        {#each RATES as option (option)}
          <button
            type="button"
            class={[
              'rounded px-1.5 py-0.5 tabular-nums',
              rate === option ? 'bg-foreground text-background' : 'hover:text-foreground',
            ]}
            onclick={() => {
              rate = option
              if (video) video.playbackRate = option
            }}>{option}×</button
          >
        {/each}
        <span class="ml-auto"
          >1 video second ≈ {Math.round(scale)} real seconds{note?.video_seconds
            ? ''
            : ' (until the video loads)'}</span
        >
      </div>
      <LapseTimeline {length} {segments} {currentTime} {preview} onseek={seek} />
    {/if}

    <p class="text-sm">
      Counts <span class="font-semibold tabular-nums">{formatSeconds(approved)}</span>
      of {formatSeconds(recording.seconds)} recorded
    </p>

    {#if segments.length}
      <ul class="space-y-1">
        {#each segments as segment, i (segment.start)}
          <li
            class={[
              'flex items-center gap-2 rounded px-2 py-1 text-xs',
              segment.type === 'removed'
                ? 'bg-red-500/10 text-red-800 dark:text-red-200'
                : 'bg-amber-500/10 text-amber-800 dark:text-amber-200',
            ]}
          >
            <button
              type="button"
              class="tabular-nums underline-offset-2 hover:underline"
              onclick={() => seek(segment.start)}>{timestamp(segment.start)}–{timestamp(segment.end)}</button
            >
            <span class="font-medium capitalize">{segment.type}</span>
            <span class="min-w-0 flex-1 truncate">{segment.reason}</span>
            <span class="tabular-nums">
              −{formatSeconds(cutSeconds(segment, scale))}{segment.type === 'deflated'
                ? ` (${100 - (segment.percent ?? 0)}% counts)`
                : ''}
            </span>
            {#if editable}
              <button
                type="button"
                aria-label="Delete this stretch"
                class="text-muted-foreground hover:text-foreground"
                onclick={() => update({ segments: segments.filter((_, j) => j !== i) })}
                ><Trash class="size-3" /></button
              >
            {/if}
          </li>
        {/each}
      </ul>
    {/if}

    {#if editable}
      {#if adding}
        <SegmentForm
          type={adding}
          {length}
          {scale}
          {currentTime}
          {segments}
          onpreview={(next) => (preview = next)}
          onadd={(segment) => {
            update({ segments: [...segments, segment].sort((a, b) => a.start - b.start) })
            adding = null
            preview = null
          }}
          oncancel={() => {
            adding = null
            preview = null
          }}
        />
      {:else}
        <div class="flex flex-wrap gap-2">
          <Button variant="outline" size="sm" onclick={() => (adding = 'removed')}>
            <MinusCircle data-icon="inline-start" /> Remove time
          </Button>
          <Button variant="outline" size="sm" onclick={() => (adding = 'deflated')}>
            <Gauge data-icon="inline-start" /> Deflate time
          </Button>
          <label class="ml-auto inline-flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={note?.reviewed ?? false}
              onchange={(event) => update({ reviewed: event.currentTarget.checked })}
            />
            Reviewed
          </label>
        </div>
      {/if}
      <Textarea
        value={note?.description ?? ''}
        rows={2}
        placeholder="What it shows (staff only)"
        onchange={(event) => update({ description: event.currentTarget.value })}
      />
    {:else if note?.description}
      <p class="text-sm whitespace-pre-line text-muted-foreground">{note.description}</p>
    {/if}
  </Card.Content>
</Card.Root>
