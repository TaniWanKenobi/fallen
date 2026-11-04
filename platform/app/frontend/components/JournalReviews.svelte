<script lang="ts" module>
  import type { ProgressReview } from '@/types'

  // The project page's journal review prop (ProjectsController#journal_review_props).
  export interface JournalReviewProps {
    reviews: ProgressReview[]
    // Why the team can't ask for a review now; null if they can, or if they aren't on the team.
    request_blocker: string | null
    can_request: boolean
  }
</script>

<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Markdown from '@/components/Markdown.svelte'
  import { formatDate } from '@/lib/format'
  import * as sfx from '@/lib/sfx'
  import { projectReviewRequest } from '@/routes'

  // Journal review on a project's page: asking a reviewer to look now, and what reviewers said, newest first: the same
  // feedback posted in its thread.
  let { projectId, reviews, request_blocker, can_request }: JournalReviewProps & { projectId: string } =
    $props()

  let asking = $state(false)
  let note = $state('')
  let sending = $state(false)
  const teammate = $derived(can_request || request_blocker != null)

  function ask() {
    sending = true
    router.post(
      projectReviewRequest(projectId).url,
      { note: note.trim() },
      { preserveScroll: true, onFinish: () => (sending = false), onSuccess: () => (asking = false) },
    )
  }
</script>

{#if reviews.length > 0 || teammate}
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

    {#if reviews.length > 0}
      <ul class="mt-4 space-y-4">
        {#each reviews as review (review.id)}
          <li>
            <p class="font-outfit text-sm text-sky-ice/70">Reviewed {formatDate(review.created_at)}</p>
            {#if review.feedback}
              <Markdown
                source={review.feedback}
                photos={[]}
                glass
                class="mt-1.5 border-l-2 border-white/25 pl-3 text-sm [&>:first-child]:mt-0 [&>:last-child]:mb-0"
              />
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </section>
{/if}
