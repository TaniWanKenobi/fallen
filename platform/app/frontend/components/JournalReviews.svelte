<script lang="ts" module>
  import type { ProgressReview, ReviewTodo } from '@/types'

  // The project page's journal review prop (ProjectsController#journal_review_props).
  export interface JournalReviewProps {
    reviews: ProgressReview[]
    todos: ReviewTodo[]
    // The signed-in person's XP held back until the to-dos are fixed.
    held_xp: number
    // There's something to fix and nothing held yet: a second check back in a row would hold XP.
    xp_warning: boolean
    // Why the team can't ask for a review now; null if they can, or if they aren't on the team.
    request_blocker: string | null
    can_request: boolean
  }
</script>

<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { formatDate } from '@/lib/format'
  import * as sfx from '@/lib/sfx'
  import { projectReviewRequest, reviewTodo } from '@/routes'

  // Journal review on a project's page: what's left to fix from the last check back (ticked off here), XP held until
  // it is, asking a reviewer to look now, and what reviewers said, newest first: the same feedback posted in its
  // thread.
  let {
    projectId,
    reviews,
    todos,
    held_xp,
    xp_warning,
    request_blocker,
    can_request,
  }: JournalReviewProps & { projectId: string } = $props()

  let asking = $state(false)
  let note = $state('')
  let sending = $state(false)
  const teammate = $derived(can_request || request_blocker != null)

  // Reviewers paste links to guides into their feedback; split on them (capturing) so they render as links.
  const LINK = /(https?:\/\/[^\s<>"']+[^\s<>"'.,;:!?)\]])/

  function tick(id: string, done: boolean) {
    sfx.select()
    router.patch(reviewTodo(id).url, { done }, { preserveScroll: true, only: ['journal_review'] })
  }

  function ask() {
    sending = true
    router.post(
      projectReviewRequest(projectId).url,
      { note: note.trim() },
      { preserveScroll: true, onFinish: () => (sending = false), onSuccess: () => (asking = false) },
    )
  }
</script>

{#if reviews.length > 0 || todos.length > 0 || teammate}
  <section class="glass px-5 py-5 md:px-6">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div class="min-w-0 flex-1 basis-64">
        <h2 class="font-montserrat text-lg font-semibold text-white">Journal reviews</h2>
        <p class="mt-1 font-outfit text-sm text-sky-ice/70">
          A reviewer reads your journals as you go and tells you what to keep doing and what to fix, so you
          can learn before the project is done.
        </p>
      </div>
      {#if can_request && !asking}
        <button type="button" class="pill-glass h-10 text-sm" onclick={() => (sfx.select(), (asking = true))}
          >Ask for a review</button
        >
      {/if}
    </div>

    {#if asking}
      <div class="mt-4 space-y-2">
        <label for="review-request-note" class="block font-outfit text-sm text-pale-blue"
          >Anything you'd like them to look at? <span class="text-sky-ice/50">(optional)</span></label
        >
        <textarea
          id="review-request-note"
          bind:value={note}
          maxlength="1000"
          rows="3"
          placeholder="I'm not sure my journals explain the wiring well enough..."
          class="block w-full resize-y rounded-[4px] border border-white/15 bg-black/20 px-3 py-2 font-outfit text-sm text-white placeholder:text-sky-ice/40"
        ></textarea>
        <div class="flex gap-2">
          <button type="button" class="pill-cream h-10 text-sm" disabled={sending} onclick={ask}
            >{sending ? 'Asking...' : 'Ask a reviewer'}</button
          >
          <button type="button" class="pill-glass h-10 text-sm" onclick={() => (asking = false)}
            >Cancel</button
          >
        </div>
      </div>
    {:else if request_blocker}
      <p class="mt-2 font-outfit text-xs text-sky-ice/50">{request_blocker}.</p>
    {/if}

    {#if todos.length > 0}
      <div class="mt-4 rounded-[4px] border border-saffron/40 bg-black/10 px-4 py-3">
        <p class="font-outfit text-sm font-semibold text-white">To fix before the next review</p>
        <ul class="mt-2 space-y-1.5">
          {#each todos as todo (todo.id)}
            <li>
              <label class="flex cursor-pointer items-start gap-2.5 font-outfit text-sm text-pale-blue">
                <input
                  type="checkbox"
                  checked={todo.done}
                  disabled={!teammate}
                  onchange={(event) => tick(todo.id, event.currentTarget.checked)}
                  class="mt-1 size-4 shrink-0 accent-saffron"
                />
                <span class={todo.done ? 'text-sky-ice/50 line-through' : ''}>{todo.body}</span>
              </label>
            </li>
          {/each}
        </ul>
        {#if held_xp > 0}
          <p class="mt-3 font-outfit text-xs text-sky-ice/70">
            {held_xp} of your XP is held back until a reviewer sees these fixed. Fix them in your next journals
            and it comes back.
          </p>
        {:else if xp_warning}
          <p class="mt-3 font-outfit text-xs text-sky-ice/70">
            Fix these in your next journals. If the next review still finds them, some of the XP from your new
            journals is held back until they're fixed.
          </p>
        {/if}
      </div>
    {/if}

    {#if reviews.length > 0}
      <ul class="mt-4 space-y-4">
        {#each reviews as review (review.id)}
          <li>
            <p class="font-outfit text-sm text-sky-ice/70">
              <span class={review.verdict === 'approved' ? 'text-emerald-300' : 'text-saffron'}>
                {review.verdict === 'approved' ? 'Looking good' : 'A few things to work on'}
              </span>
              · {formatDate(review.created_at)}
            </p>
            {#if Object.keys(review.journal_notes).length}
              <p class="mt-1 font-outfit text-xs text-sky-ice/60">
                Plus notes on {Object.keys(review.journal_notes).length}
                {Object.keys(review.journal_notes).length === 1 ? 'journal' : 'journals'}, shown under each
                one below.
              </p>
            {/if}
            {#if review.feedback}
              <blockquote
                class={[
                  'mt-1.5 border-l-2 pl-3 font-outfit text-sm whitespace-pre-wrap text-pale-blue',
                  review.verdict === 'approved' ? 'border-white/25' : 'border-saffron/60',
                ]}
              >
                {#each review.feedback.split(LINK) as part, i (i)}{#if i % 2}<a
                      href={part}
                      target="_blank"
                      rel="noopener"
                      class="underline decoration-white/40 hover:decoration-white">{part}</a
                    >{:else}{part}{/if}{/each}
              </blockquote>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </section>
{/if}
