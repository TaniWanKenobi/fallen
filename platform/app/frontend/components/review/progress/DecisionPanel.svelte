<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Loader from '@lucide/svelte/icons/loader'
  import Send from '@lucide/svelte/icons/send'
  import { Button } from '@/components/admin/ui/button'
  import { Checkbox } from '@/components/admin/ui/checkbox'
  import { Separator } from '@/components/admin/ui/separator'
  import Markdown from '@/components/Markdown.svelte'
  import Key from '@/components/review/Key.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import FeedbackEditor from '@/components/review/progress/FeedbackEditor.svelte'
  import VerdictBadge from '@/components/review/progress/VerdictBadge.svelte'
  import { reveal } from '@/components/review/motion'
  import { formatDate, formatDateTime, formatMinutes, timeAgo } from '@/lib/format'
  import type { ProgressPage, ProgressVerdict } from '@/lib/progressReview'
  import { RAISED } from '@/lib/review.svelte'
  import { takeOverJournalReviewProject } from '@/routes'

  // The right-hand column of the journal review page: where the project stands, the feedback for
  // the team and the decision, then the reviews before this one and the reviewers' notes.
  let {
    page,
    feedback = $bindable(),
    needsFix = $bindable(),
    journalNotes,
    submitting,
    pending,
    errors,
    onDecide,
  }: {
    page: ProgressPage
    feedback: string
    // Ticked, the review goes out as a check back; unticked, as an approval.
    needsFix: boolean
    // How many journals this review has a note on.
    journalNotes: number
    submitting: boolean
    pending: ProgressVerdict | null
    errors: Record<string, string>
    onDecide: (verdict: ProgressVerdict) => void
  } = $props()

  const mod = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl+'
  const s = $derived(page.status)
  const checkBackBlocker = $derived(!feedback.trim() ? 'Write feedback so they know what to work on' : null)
  const holder = $derived(
    s.claimed_by && s.claim_expires_at && new Date(s.claim_expires_at) > new Date() ? s.claimed_by : null,
  )

  const verdict = $derived<ProgressVerdict>(needsFix ? 'check_back' : 'approved')
  const blocker = $derived(needsFix ? checkBackBlocker : null)

  // Why a check back can't go out yet; an approval always can.
  export const blockerFor = (v: ProgressVerdict) => (v === 'check_back' ? checkBackBlocker : null)

  let feedbackEditor: FeedbackEditor | undefined = $state()
  export const focusFeedback = () => feedbackEditor?.focus()
</script>

<div class="space-y-4 p-4">
  <div class="space-y-1.5">
    <h3 class="text-xs font-semibold tracking-wide text-muted-foreground uppercase">Journal review</h3>
    <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
      <dt class="text-muted-foreground" title="Hours journaled on Fallen; transferred hours don't count">
        Logged
      </dt>
      <dd class="font-mono">{formatMinutes(s.logged_minutes)}</dd>
      <dt class="text-muted-foreground">Reviews</dt>
      <dd>{s.reviews_count ? `${s.reviews_count}, ${s.approvals_count} approved` : 'This is the first'}</dd>
      {#if s.last_reviewed_at}
        <dt class="text-muted-foreground">Last</dt>
        <dd>{formatDate(s.last_reviewed_at)}</dd>
      {/if}
      {#if s.due_since}
        <dt class="text-muted-foreground">Waiting</dt>
        <dd>{timeAgo(s.due_since).replace(' ago', '')}</dd>
      {/if}
    </dl>
  </div>

  {#if s.added}
    <p class="rounded-md border border-border bg-muted/40 px-2.5 py-2 text-xs text-muted-foreground">
      Added to the queue by {s.added.by?.name ?? 'an admin'}, {formatDate(s.added.at)}.
    </p>
  {/if}

  {#if s.request}
    <div
      class="rounded-md border border-pink-200 bg-pink-50 px-2.5 py-2 text-sm dark:border-pink-900 dark:bg-pink-950/40"
    >
      <p class="text-xs font-medium text-pink-700 dark:text-pink-300">
        {s.request.by?.name ?? 'The team'} asked for this review, {formatDate(s.request.at)}
      </p>
      {#if s.request.note}<p class="mt-0.5 whitespace-pre-wrap">{s.request.note}</p>{/if}
    </div>
  {/if}

  {#if s.flagged_at}
    <div
      class="rounded-md border border-red-200 bg-red-50 px-2.5 py-2 text-sm dark:border-red-900 dark:bg-red-950/40"
    >
      <p class="text-xs font-medium text-red-700 dark:text-red-400">
        Flagged for AI{s.flagged_by ? ` by ${s.flagged_by.name}` : ''}
      </p>
      <p class="mt-0.5 whitespace-pre-wrap">{s.flag_reason}</p>
    </div>
  {:else if !s.due_since}
    <p class="rounded-md border border-border bg-muted/40 p-3 text-sm text-muted-foreground">
      Not waiting for a review.
      {#if page.project.submitted && s.reviews_count}It’s been submitted, so journal review is done.
      {:else if s.waiting_since}It comes back with their next journal of {page.check_back_min_minutes}+ min.
      {:else if s.next_due_minutes}It comes back at {formatMinutes(s.next_due_minutes)} logged.{/if}
    </p>
  {:else if !page.can.decide}
    <div class="rounded-md border border-border bg-muted/40 p-3 text-sm">
      {#if holder}
        <PersonChip person={holder} class="font-medium" />
        <p class="mt-1 text-xs text-muted-foreground">
          has this open. Their hold ends {timeAgo(s.claim_expires_at!)} unless they keep working.
        </p>
        {#if page.can.take_over}
          <Button
            size="sm"
            class="mt-2.5 w-full {RAISED.plain}"
            onclick={() =>
              router.post(
                takeOverJournalReviewProject(page.project.id, { query: page.skip ? { skip: page.skip } : {} })
                  .url,
              )}>Take it over</Button
          >
        {/if}
      {:else}
        <p class="text-muted-foreground">
          {page.can.own
            ? 'You’re on this project’s team, so someone else has to review it. You can still read it.'
            : 'You can read this, but not review it.'}
        </p>
      {/if}
    </div>
  {/if}

  {#if page.can.decide}
    <div class="space-y-2">
      <!-- The editor isn't a form field, so the label names it by id and focuses it on click. -->
      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
      <label
        id="feedback-label"
        class="flex items-start gap-1.5 text-xs text-muted-foreground"
        onclick={focusFeedback}
      >
        Feedback <span class="text-muted-foreground/60">(posted in their thread and on the project page)</span
        >
        <Key>{mod}F</Key>
      </label>
      <FeedbackEditor
        bind:this={feedbackEditor}
        labelledby="feedback-label"
        bind:value={feedback}
        placeholder="Start with one thing they did well. Then what to do better in the next journals..."
      />
      {#if errors.feedback}<p class="text-xs text-red-600">{errors.feedback}</p>{/if}
      <p class="text-xs text-muted-foreground">
        {journalNotes
          ? `Plus your notes on ${journalNotes} ${journalNotes === 1 ? 'journal' : 'journals'}, kept for reviewers.`
          : 'Add a note for reviewers on a particular journal from its card (M). The team doesn’t see it.'}
      </p>
    </div>

    <label
      class={[
        'flex cursor-pointer items-center gap-3 rounded-lg border-2 px-3 py-3 transition-colors',
        needsFix
          ? 'border-amber-400 bg-amber-50 dark:border-amber-600 dark:bg-amber-950/40'
          : 'border-border hover:border-foreground/30',
      ]}
    >
      <Checkbox
        checked={needsFix}
        onCheckedChange={(value) => (needsFix = value === true)}
        class="size-6 [&_svg]:size-5"
      />
      <span class="min-w-0">
        <span class="block text-sm font-medium">Check back next journal</span>
        <span class="block text-xs text-muted-foreground">If the journal needs many changes</span>
        {#if needsFix}<span class="block pt-0.5 text-xs text-muted-foreground/70"
            >Only reviewers see this. It comes back with their next journal of {page.check_back_min_minutes}+
            min.</span
          >{/if}
      </span>
      <Key class="ml-auto">{mod}E</Key>
    </label>

    {@const shown = Object.entries(errors).filter(([key]) => key !== 'feedback')}
    {#if shown.length}
      <ul
        transition:reveal
        class="space-y-1 rounded-md border border-red-200 bg-red-50 px-2.5 py-2 text-xs text-red-700 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300"
      >
        {#each shown as [field, message] (field)}<li>{message}</li>{/each}
      </ul>
    {/if}

    <div class="space-y-2 pt-1">
      <Button
        class="w-full cursor-pointer {needsFix ? RAISED.warning : RAISED.success}"
        disabled={submitting || !!blocker}
        title={blocker ?? undefined}
        onclick={() => onDecide(verdict)}
      >
        {#if submitting && pending !== 'dismissed'}<Loader
            class="animate-spin"
            data-icon="inline-start"
          />{:else}<Send data-icon="inline-start" />{/if}
        Give feedback
      </Button>
      <p class="text-center text-xs text-muted-foreground">
        {#if blocker}<span class="block pb-1">{blocker}.</span>{/if}
        {mod}Enter to send
      </p>
      {#if page.can.dismiss}
        <Button
          variant="ghost"
          size="sm"
          class="w-full text-muted-foreground"
          disabled={submitting}
          title="Nothing is sent. Use it when their new journal is too small to judge."
          onclick={() => onDecide('dismissed')}
        >
          Not enough new yet: wait for one more journal
        </Button>
      {/if}
    </div>
  {/if}

  {#if page.history.length}
    <Separator />
    <div class="space-y-3">
      <h3 class="text-xs font-semibold tracking-wide text-muted-foreground uppercase">Past reviews</h3>
      {#each page.history as review (review.id)}
        <div class="space-y-1 text-sm">
          <div class="flex flex-wrap items-center gap-1.5 text-xs text-muted-foreground">
            <VerdictBadge verdict={review.verdict} />
            <span title={formatDateTime(review.created_at)}>{formatDate(review.created_at)}</span>
            <span>at {formatMinutes(review.logged_minutes)}</span>
            {#if review.reviewer}<PersonChip person={review.reviewer} />{/if}
          </div>
          {#if review.feedback}
            <Markdown
              source={review.feedback}
              photos={[]}
              admin
              class="border-l-2 border-border pl-2 text-[13px] text-muted-foreground [&>:first-child]:mt-0 [&>:last-child]:mb-0"
            />
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  {#if page.notes.length}
    <Separator />
    <div class="space-y-2">
      <h3 class="text-xs font-semibold tracking-wide text-muted-foreground uppercase">Reviewer notes</h3>
      {#each page.notes as note (note.id)}
        <div class="text-[13px]">
          <p class="text-xs text-muted-foreground">
            {note.author?.name ?? 'Someone'}, {formatDate(note.created_at)}
          </p>
          <p class="whitespace-pre-wrap">{note.body}</p>
        </div>
      {/each}
    </div>
  {/if}
</div>
