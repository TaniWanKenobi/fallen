<script lang="ts">
  import Check from '@lucide/svelte/icons/check'
  import CornerDownLeft from '@lucide/svelte/icons/corner-down-left'
  import Loader from '@lucide/svelte/icons/loader'
  import WandSparkles from '@lucide/svelte/icons/wand-sparkles'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Button } from '@/components/admin/ui/button'
  import { Kbd } from '@/components/admin/ui/kbd'
  import { Textarea } from '@/components/admin/ui/textarea'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import StatusBadge from '@/components/review/StatusBadge.svelte'
  import { formatDateTime, formatMinutes } from '@/lib/format'
  import {
    draftFeedback,
    journalDecided,
    type Answer,
    type ReviewDraft,
    type ReviewPage,
    type Verdict,
  } from '@/lib/review.svelte'
  import { money } from '@/lib/submission'

  let {
    page,
    draft = $bindable(),
    countedMinutes,
    fundedCents,
    submitting,
    pending,
    errors,
    onDecide,
    feedbackRef = $bindable(),
    internalRef = $bindable(),
  }: {
    page: ReviewPage
    draft: ReviewDraft
    countedMinutes: number
    fundedCents: number
    submitting: boolean
    pending: Verdict | null
    errors: Record<string, string>
    onDecide: (verdict: Verdict) => void
    feedbackRef?: HTMLTextAreaElement | null
    internalRef?: HTMLTextAreaElement | null
  } = $props()

  const mod = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl+'
  const s = $derived(page.submission)
  const decided = $derived(s.status !== 'pending')
  const questions = $derived(Object.entries(page.options.rubric))
  const answered = $derived(questions.every(([key]) => draft.rubric[key]))
  const journalsLeft = $derived(page.journals.filter((j) => !journalDecided(draft.journals[j.id])).length)
  const journalReasonsMissing = $derived(
    page.journals.some((j) => {
      const call = draft.journals[j.id]
      return call?.minutes != null && call.minutes < (j.duration_minutes ?? 0) && !call.reason
    }),
  )
  const itemsLeft = $derived(s.bom_items.filter((i) => !draft.bom[i.id]?.verdict).length)
  const itemReasonsMissing = $derived(
    s.bom_items.some((i) => {
      const call = draft.bom[i.id]
      return (call?.verdict === 'cut' || call?.verdict === 'adjusted') && !call.reason
    }),
  )

  const common = $derived(
    !answered
      ? 'Answer every question'
      : journalsLeft
        ? `Decide the ${journalsLeft} journal${journalsLeft === 1 ? '' : 's'} left`
        : journalReasonsMissing
          ? 'Give a reason for every journal you cut'
          : !draft.internal.trim()
            ? 'Write the internal reason'
            : null,
  )
  const approveBlocker = $derived(
    common ??
      (itemsLeft
        ? `Decide the ${itemsLeft} part${itemsLeft === 1 ? '' : 's'} left`
        : itemReasonsMissing
          ? 'Give a reason for every part you cut or lower'
          : null),
  )
  const returnBlocker = $derived(
    common ?? (!draft.feedback.trim() ? 'Write feedback so they know what to change' : null),
  )

  function writeFeedback() {
    const text = draftFeedback(page, draft)
    draft.feedback = draft.feedback.trim() ? `${draft.feedback.trim()}\n\n${text}` : text
  }

  export const blockers = () => ({ approve: approveBlocker, return: returnBlocker })
</script>

<div class="space-y-4 p-4">
  {#if decided}
    <div class="space-y-2">
      <h3 class="text-xs font-semibold tracking-wide text-muted-foreground uppercase">Review complete</h3>
      <div class="flex items-center gap-2">
        <StatusBadge status={s.status} class="text-xs" />
        {#if s.reviewer}<span class="text-xs text-muted-foreground"
            >by {s.reviewer.name}, {formatDateTime(s.decided_at)}</span
          >{/if}
      </div>
      {#if s.status === 'approved'}
        <p class="font-mono text-lg">
          {money(s.approved_cents)}
          <span class="text-xs text-muted-foreground">funding, {s.payout_status ?? 'nothing to send'}</span>
        </p>
      {/if}
    </div>
  {:else if s.flagged_at}
    <div
      class="rounded-md border border-red-300 bg-red-50 p-3 text-sm dark:border-red-900 dark:bg-red-950/40"
    >
      <p class="font-semibold text-red-700 dark:text-red-300">Flagged for fraud</p>
      <p class="mt-1 whitespace-pre-wrap">{s.flag_reason}</p>
    </div>
  {:else if !page.can.decide}
    <div class="rounded-md border border-border bg-muted/40 p-3 text-sm">
      {#if s.claimed_by && s.claim_expires_at && new Date(s.claim_expires_at) > new Date()}
        <PersonChip person={s.claimed_by} class="font-medium" /> is reviewing this right now. You can read along.
      {:else if page.project.team.some((p) => p.id === s.submitter.id)}
        You can read this, but not review it.
      {/if}
    </div>
  {/if}

  <section class="space-y-2">
    <h3 class="text-xs font-semibold tracking-wide text-muted-foreground uppercase">Rubric</h3>
    {#each questions as [key, question] (key)}
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm leading-tight">{question}</span>
        <div
          class="inline-flex shrink-0 overflow-hidden rounded-md border border-border text-xs"
          role="radiogroup"
          aria-label={question}
        >
          {#each page.options.answers as answer (answer)}
            {@const on = draft.rubric[key] === answer}
            <button
              type="button"
              role="radio"
              aria-checked={on}
              disabled={decided || !page.can.decide}
              onclick={() => (draft.rubric[key] = answer as Answer)}
              class={[
                'border-r border-border px-2 py-1 capitalize last:border-r-0 disabled:cursor-default',
                on && answer === 'yes' && 'bg-emerald-600 text-white',
                on && answer === 'partly' && 'bg-amber-500 text-white',
                on && answer === 'no' && 'bg-red-600 text-white',
                !on && 'bg-background hover:bg-muted',
              ]}>{answer}</button
            >
          {/each}
        </div>
      </div>
    {/each}
  </section>

  <section class="grid grid-cols-2 gap-2 text-xs">
    <div class="rounded-md border border-border p-2">
      <p class="text-muted-foreground">Time that counts</p>
      <p class="font-mono text-sm">
        {formatMinutes(countedMinutes)}
        <span class="text-muted-foreground">/ {formatMinutes(page.project.logged_minutes)}</span>
      </p>
      {#if !decided && journalsLeft}<p class="text-amber-600 dark:text-amber-400">
          {journalsLeft} journals left
        </p>{/if}
    </div>
    <div class="rounded-md border border-border p-2">
      <p class="text-muted-foreground">Funding</p>
      <p class="font-mono text-sm">
        {money(fundedCents)} <span class="text-muted-foreground">/ {money(s.requested_cents)}</span>
      </p>
      {#if !decided && itemsLeft}<p class="text-amber-600 dark:text-amber-400">{itemsLeft} parts left</p>{/if}
    </div>
  </section>

  <div class="h-px bg-border"></div>

  <section class="space-y-1.5">
    <label for="internal-reason" class="flex items-center gap-1.5 text-xs text-muted-foreground">
      Internal reason <span class="text-muted-foreground/60">(reviewers only)</span>
      {#if !decided}<Kbd class="ml-auto">{mod}J</Kbd>{/if}
    </label>
    <Textarea
      id="internal-reason"
      bind:ref={internalRef}
      bind:value={draft.internal}
      readonly={decided || !page.can.decide}
      placeholder="Why you decided this, for the next reviewer and for audits."
      class="h-20 resize-y text-sm"
    />
    {#if errors.internal_reason}<p class="text-xs text-red-600">{errors.internal_reason}</p>{/if}
  </section>

  <section class="space-y-1.5">
    <div class="flex items-center gap-1.5 text-xs text-muted-foreground">
      <label for="feedback"
        >Feedback <span class="text-muted-foreground/60">(sent to them on Slack)</span></label
      >
      {#if !decided}<Kbd class="ml-auto">{mod}F</Kbd>{/if}
    </div>
    <Textarea
      id="feedback"
      bind:ref={feedbackRef}
      bind:value={draft.feedback}
      readonly={decided || !page.can.decide}
      placeholder="What they did well, and what to change. Needed to send it back."
      class="h-36 resize-y text-sm"
    />
    {#if !decided && page.can.decide}
      <Button
        size="sm"
        variant="ghost"
        class="w-full justify-start text-muted-foreground"
        onclick={writeFeedback}
      >
        <WandSparkles data-icon="inline-start" /> Write it from my calls
      </Button>
    {/if}
    {#if errors.feedback}<p class="text-xs text-red-600">{errors.feedback}</p>{/if}
  </section>

  {#if !decided && page.can.decide}
    {@const shown = Object.entries(errors).filter(([k]) => !['feedback', 'internal_reason'].includes(k))}
    {#if shown.length}
      <ul
        class="space-y-1 rounded-md bg-red-50 p-2 text-xs text-red-700 dark:bg-red-950/40 dark:text-red-300"
      >
        {#each shown as [field, message] (field)}<li>{message}</li>{/each}
      </ul>
    {/if}

    <div class="space-y-2 pt-1">
      <div class="grid grid-cols-2 gap-2">
        <Button
          class="bg-emerald-600 text-white hover:bg-emerald-700"
          disabled={submitting || !!approveBlocker}
          title={approveBlocker ?? undefined}
          onclick={() => onDecide('approved')}
        >
          {#if submitting && pending === 'approved'}<Loader
              class="animate-spin"
              data-icon="inline-start"
            />{:else}<Check data-icon="inline-start" />{/if}
          Approve <Kbd class="ml-1 bg-emerald-700/60 text-emerald-50">{mod}P</Kbd>
        </Button>
        <Button
          class="bg-amber-600 text-white hover:bg-amber-700"
          disabled={submitting || !!returnBlocker}
          title={returnBlocker ?? undefined}
          onclick={() => onDecide('returned')}
        >
          {#if submitting && pending === 'returned'}<Loader
              class="animate-spin"
              data-icon="inline-start"
            />{:else}<CornerDownLeft data-icon="inline-start" />{/if}
          Return <Kbd class="ml-1 bg-amber-700/60 text-amber-50">{mod}E</Kbd>
        </Button>
      </div>
      <p class="min-h-4 text-center text-xs text-muted-foreground">
        {approveBlocker ?? `Approving sends ${money(fundedCents)}.`}
      </p>

      {#if page.can.reject}
        <AlertDialog.Root>
          <AlertDialog.Trigger>
            {#snippet child({ props })}
              <Button
                {...props}
                variant="ghost"
                size="sm"
                class="w-full text-red-600"
                disabled={submitting || !!returnBlocker}>Reject for good</Button
              >
            {/snippet}
          </AlertDialog.Trigger>
          <AlertDialog.Content>
            <AlertDialog.Header>
              <AlertDialog.Title>Reject {page.project.title} for good?</AlertDialog.Title>
              <AlertDialog.Description>
                They can’t submit it again. Use this for fraud or plagiarism only; anything fixable should be
                returned.
              </AlertDialog.Description>
            </AlertDialog.Header>
            <AlertDialog.Footer>
              <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
              <AlertDialog.Action variant="destructive" onclick={() => onDecide('rejected')}
                >Reject</AlertDialog.Action
              >
            </AlertDialog.Footer>
          </AlertDialog.Content>
        </AlertDialog.Root>
      {/if}
    </div>
  {/if}
</div>
