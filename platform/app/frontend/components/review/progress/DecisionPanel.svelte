<script lang="ts">
  import { tick } from 'svelte'
  import { router } from '@inertiajs/svelte'
  import Check from '@lucide/svelte/icons/check'
  import Loader from '@lucide/svelte/icons/loader'
  import Plus from '@lucide/svelte/icons/plus'
  import RotateCcw from '@lucide/svelte/icons/rotate-ccw'
  import { Button } from '@/components/admin/ui/button'
  import { Checkbox } from '@/components/admin/ui/checkbox'
  import { Separator } from '@/components/admin/ui/separator'
  import { Textarea } from '@/components/admin/ui/textarea'
  import Key from '@/components/review/Key.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import TodosEditor from '@/components/review/progress/TodosEditor.svelte'
  import VerdictBadge from '@/components/review/progress/VerdictBadge.svelte'
  import { reveal } from '@/components/review/motion'
  import { formatDate, formatDateTime, formatMinutes, timeAgo } from '@/lib/format'
  import type { ProgressPage, ProgressVerdict } from '@/lib/progressReview'
  import { RAISED } from '@/lib/review.svelte'
  import { takeOverJournalReviewProject } from '@/routes'

  // The right-hand column of the journal review page: where the project stands, the quality checks, the feedback for
  // the team and the decision, then the reviews before this one and the reviewers' notes.
  let {
    page,
    checks = $bindable(),
    feedback = $bindable(),
    todos = $bindable(),
    reopen = $bindable(),
    journalNotes,
    submitting,
    pending,
    errors,
    onDecide,
    feedbackRef = $bindable(),
  }: {
    page: ProgressPage
    checks: Record<string, boolean>
    feedback: string
    todos: string[]
    reopen: string[]
    // How many journals this review has a note on.
    journalNotes: number
    submitting: boolean
    pending: ProgressVerdict | null
    errors: Record<string, string>
    onDecide: (verdict: ProgressVerdict) => void
    feedbackRef?: HTMLTextAreaElement | null
  } = $props()

  const mod = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl+'
  const s = $derived(page.status)
  const unchecked = $derived(page.required_checks.filter((key) => !checks[key]).length)
  const approveBlocker = $derived(
    unchecked ? `Tick the ${unchecked} must-have${unchecked === 1 ? '' : 's'} left` : null,
  )
  // A check back needs something left to fix: a new to-do, a reopened one, or an old one they haven't ticked.
  const somethingToFix = $derived(
    todos.some((t) => t.trim()) || reopen.length > 0 || page.todos.some((t) => !t.done),
  )
  const checkBackBlocker = $derived(
    !feedback.trim()
      ? 'Write feedback so they know what to work on'
      : !somethingToFix
        ? 'Add at least one thing to fix'
        : null,
  )
  const holder = $derived(
    s.claimed_by && s.claim_expires_at && new Date(s.claim_expires_at) > new Date() ? s.claimed_by : null,
  )
  const afterApprove = $derived(
    page.project.submitted
      ? 'It’s been submitted, so this is its last journal review.'
      : `Approving brings it back at ${formatMinutes(s.logged_minutes + s.next_gap_minutes)} logged (${formatMinutes(s.next_gap_minutes)} more).`,
  )

  export const blockers = () => ({ approve: approveBlocker, check_back: checkBackBlocker })

  // Puts a resource's link into the feedback where the cursor is (at the end if it isn't in there), on its own line.
  async function addResource(resource: { label: string; url: string }) {
    const at =
      document.activeElement === feedbackRef
        ? (feedbackRef?.selectionStart ?? feedback.length)
        : feedback.length
    const before = feedback.slice(0, at)
    const after = feedback.slice(at)
    const line = `${before && !before.endsWith('\n') ? '\n' : ''}${resource.label}: ${resource.url}${after.startsWith('\n') ? '' : '\n'}`
    feedback = before + line + after
    await tick()
    feedbackRef?.focus()
    feedbackRef?.setSelectionRange(before.length + line.length, before.length + line.length)
  }
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

  <div class="space-y-1.5">
    <h3 class="text-xs font-semibold tracking-wide text-muted-foreground uppercase">Who's building</h3>
    {#if page.people}
      <ul class="space-y-1 text-sm">
        {#each page.people as record (record.person.id)}
          <li class="flex flex-wrap items-baseline gap-x-1.5">
            <PersonChip person={record.person} class="font-medium" />
            <span class="text-xs text-muted-foreground">
              {#if record.other_projects === 0}
                <span class="font-medium text-sky-700 dark:text-sky-300">First project</span>
              {:else}
                {record.other_projects} other {record.other_projects === 1
                  ? 'project'
                  : 'projects'}{#if record.approved + record.check_backs}, {record.approved} approved / {record.check_backs}
                  checked back there{:else}, never journal reviewed{/if}
              {/if}
              · joined {formatDate(record.joined_at)}
            </span>
          </li>
        {/each}
      </ul>
    {:else}
      <p class="text-xs text-muted-foreground">Loading...</p>
    {/if}
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
      {:else if s.waiting_since}It comes back with their next journal.
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
      <p class="text-xs text-muted-foreground">
        Checks <span class="text-muted-foreground/60">(only reviewers see these)</span>
      </p>
      {#each Object.entries(page.checks) as [key, text] (key)}
        {@const required = page.required_checks.includes(key)}
        <label class="flex cursor-pointer items-start gap-2 text-[13px] leading-snug">
          <Checkbox
            checked={checks[key] ?? false}
            onCheckedChange={(value) => (checks[key] = value === true)}
            class="mt-0.5"
          />
          <span
            >{text}{#if required}<span
                class="ml-1 rounded bg-muted px-1 py-px text-[10px] font-medium tracking-wide text-muted-foreground uppercase"
                >must</span
              >{/if}</span
          >
        </label>
      {/each}
      <p class="text-xs text-muted-foreground/80">
        Approving needs the must-haves. Leave the others unticked to note what could be better; it doesn't
        block.
      </p>
    </div>

    <div class="space-y-2">
      <label for="feedback" class="flex items-center gap-1.5 text-xs text-muted-foreground">
        Feedback <span class="text-muted-foreground/60">(posted in their thread and on the project page)</span
        >
        <Key>{mod}F</Key>
      </label>
      <Textarea
        id="feedback"
        bind:ref={feedbackRef}
        bind:value={feedback}
        placeholder="Start with one thing they did well. Then what to do better in the next journals..."
        class="h-32 resize-y text-sm"
      />
      <p class="text-xs text-muted-foreground">
        Start with one thing they did well: beginners keep going when they hear what's working.
      </p>
      {#if errors.feedback}<p class="text-xs text-red-600">{errors.feedback}</p>{/if}
      {#if page.resources.length}
        <div class="space-y-1">
          <p class="text-xs text-muted-foreground">Add a resource</p>
          <div class="flex flex-wrap gap-1">
            {#each page.resources as resource (resource.url)}
              <button
                type="button"
                title={resource.url}
                onclick={() => addResource(resource)}
                class="flex items-center gap-1 rounded-full border border-border px-2 py-0.5 text-xs text-muted-foreground transition-colors hover:border-foreground/40 hover:text-foreground"
              >
                <Plus class="size-3" />{resource.label}
              </button>
            {/each}
          </div>
        </div>
      {/if}
      <p class="text-xs text-muted-foreground">
        {journalNotes
          ? `Plus your notes on ${journalNotes} ${journalNotes === 1 ? 'journal' : 'journals'}, sent with it.`
          : 'Add a note on a particular journal from its card (M).'}
      </p>
    </div>

    <TodosEditor {page} bind:todos bind:reopen />

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
      <div class="grid grid-cols-2 gap-2">
        <Button
          class={RAISED.success}
          disabled={submitting || !!approveBlocker}
          title={approveBlocker ?? undefined}
          onclick={() => onDecide('approved')}
        >
          {#if submitting && pending === 'approved'}<Loader
              class="animate-spin"
              data-icon="inline-start"
            />{:else}<Check data-icon="inline-start" />{/if}
          Approve
        </Button>
        <Button
          class={RAISED.warning}
          disabled={submitting || !!checkBackBlocker}
          title={checkBackBlocker ?? undefined}
          onclick={() => onDecide('check_back')}
        >
          {#if submitting && pending === 'check_back'}<Loader
              class="animate-spin"
              data-icon="inline-start"
            />{:else}<RotateCcw data-icon="inline-start" />{/if}
          Check back
        </Button>
      </div>
      <p class="text-center text-xs text-muted-foreground">
        {approveBlocker ? `${approveBlocker}.` : afterApprove}
        {#if !page.project.submitted}Checking back brings it back with their next journal.{/if}
        <span class="block pt-1">{mod}P approves, {mod}E checks back.</span>
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
      <h3 class="text-xs font-semibold tracking-wide text-muted-foreground uppercase">Earlier reviews</h3>
      {#each page.history as review (review.id)}
        <div class="space-y-1 text-sm">
          <div class="flex flex-wrap items-center gap-1.5 text-xs text-muted-foreground">
            <VerdictBadge verdict={review.verdict} />
            <span title={formatDateTime(review.created_at)}>{formatDate(review.created_at)}</span>
            <span>at {formatMinutes(review.logged_minutes)}</span>
            {#if review.reviewer}<PersonChip person={review.reviewer} />{/if}
          </div>
          {#if review.verdict !== 'dismissed'}
            {@const missed = Object.entries(page.checks).filter(([key]) => !review.checks[key])}
            {#if missed.length}
              <ul class="text-xs text-amber-700 dark:text-amber-400">
                {#each missed as [key, text] (key)}<li>✗ {text}</li>{/each}
              </ul>
            {/if}
          {/if}
          {#if review.feedback}
            <p class="border-l-2 border-border pl-2 text-[13px] whitespace-pre-wrap text-muted-foreground">
              {review.feedback}
            </p>
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
