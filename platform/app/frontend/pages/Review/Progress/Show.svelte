<script lang="ts" module>
  export { default as layout } from '@/layouts/ReviewLayout.svelte'
</script>

<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { onMount } from 'svelte'
  import * as Dialog from '@/components/admin/ui/dialog'
  import Key from '@/components/review/Key.svelte'
  import Lightbox from '@/components/review/Lightbox.svelte'
  import ResizeHandle from '@/components/review/ResizeHandle.svelte'
  import Segmented from '@/components/review/Segmented.svelte'
  import DecisionPanel from '@/components/review/progress/DecisionPanel.svelte'
  import JournalCard from '@/components/review/progress/JournalCard.svelte'
  import TopBar from '@/components/review/progress/TopBar.svelte'
  import { csrfToken } from '@/lib/csrf'
  import { formatMinutes } from '@/lib/format'
  import type { EarlierNote, ProgressPage, ProgressVerdict } from '@/lib/progressReview'
  import { toast } from '@/lib/toasts'
  import { heartbeatJournalReviewProject, journalReviewProject, journalReviewRoot } from '@/routes'

  // One project's journal review, laid out like design review: its journals on the left, the decision on the right.
  // The feedback and notes are kept in this browser until sent, and the claim is renewed while the page is open.
  let props: ProgressPage = $props()

  type Draft = {
    feedback: string
    // Ticked, the review goes out as a check back; otherwise as an approval.
    needs_fix: boolean
    journal_notes: Record<string, string>
  }
  // svelte-ignore state_referenced_locally
  const storageKey = `fallen:journal-review:${props.project.id}`
  let draft = $state<Draft>(loadDraft())
  let filter = $state<'all' | 'new'>('all')
  let focused = $state(0)
  let submitting = $state(false)
  let pending = $state<ProgressVerdict | null>(null)
  let errors = $state<Record<string, string>>({})
  let lost = $state(false)
  let helpOpen = $state(false)
  // The decision column's width, dragged from the line beside it.
  const ASIDE_DEFAULT = 320
  const ASIDE_MIN = 280
  const ASIDE_MAX = 720
  let asideWidth = $state(ASIDE_DEFAULT)
  let topBar: TopBar | undefined = $state()
  let decision: DecisionPanel | undefined = $state()
  const cards: JournalCard[] = $state([])

  const fresh = (createdAt: string) =>
    !!props.status.last_reviewed_at && new Date(createdAt) > new Date(props.status.last_reviewed_at)
  const newCount = $derived(props.journals.filter((j) => fresh(j.created_at)).length)
  const newMinutes = $derived(
    props.journals.filter((j) => fresh(j.created_at)).reduce((sum, j) => sum + (j.duration_minutes ?? 0), 0),
  )
  const shown = $derived(
    props.journals
      .map((journal, index) => ({ journal, index }))
      .filter(({ journal }) => filter === 'all' || fresh(journal.created_at)),
  )

  // Notes earlier reviews left on each journal, by journal id, newest first.
  const earlierNotes = $derived(
    props.history.reduce<Record<string, EarlierNote[]>>((byJournal, review) => {
      for (const [id, note] of Object.entries(review.journal_notes))
        (byJournal[id] ??= []).push({
          id: review.id,
          note,
          at: review.created_at,
          verdict: review.verdict,
          reviewer: review.reviewer,
        })
      return byJournal
    }, {}),
  )
  const noted = $derived(Object.values(draft.journal_notes).filter((note) => note.trim()).length)

  function loadDraft(): Draft {
    const fresh: Draft = {
      feedback: '',
      needs_fix: false,
      journal_notes: {},
    }
    try {
      const saved = localStorage.getItem(storageKey)
      if (saved) return { ...fresh, ...JSON.parse(saved) }
    } catch {
      // No storage (private window): start fresh.
    }
    return fresh
  }

  $effect(() => {
    const snapshot = JSON.stringify($state.snapshot(draft))
    try {
      localStorage.setItem(storageKey, snapshot)
    } catch {
      // Nothing to keep it in.
    }
  })

  // Keeps the claim while the page is open. Losing it stops the decision going in, so the reviewer finds out now.
  onMount(() => {
    if (!props.claimed) return
    const beat = async () => {
      try {
        const response = await fetch(heartbeatJournalReviewProject(props.project.id).url, {
          method: 'POST',
          headers: { 'X-CSRF-Token': csrfToken(), Accept: 'application/json' },
          credentials: 'same-origin',
        })
        // Only a network error is "offline, try again"; any answer that isn't a clear "still yours" means it isn't.
        const data = response.ok ? await response.json().catch(() => ({ held: false })) : { held: false }
        if (!data.held && !lost) {
          lost = true
          toast.error('Someone else has this project now. Your review wasn’t sent.', { duration: 10000 })
        }
      } catch {
        // Offline for a moment: the next beat tries again.
      }
    }
    const timer = setInterval(beat, 120_000)
    return () => clearInterval(timer)
  })

  function decide(verdict: ProgressVerdict) {
    if (!props.can.decide) return
    const blocker = decision?.blockerFor(verdict)
    if (blocker) return toast.error(blocker)
    submitting = true
    pending = verdict
    errors = {}
    router.patch(
      journalReviewProject(props.project.id, { query: props.skip ? { skip: props.skip } : {} }).url,
      {
        review: {
          verdict,
          feedback: draft.feedback,
          journal_notes: draft.journal_notes,
        },
      },
      {
        onSuccess: (page) => {
          if (Object.keys(page.props.errors ?? {}).length) return
          try {
            localStorage.removeItem(storageKey)
          } catch {
            // Nothing was kept.
          }
        },
        onError: (e) => (errors = e as Record<string, string>),
        onFinish: () => {
          submitting = false
          pending = null
        },
      },
    )
  }

  function move(by: number) {
    focused = Math.min(Math.max(focused + by, 0), props.journals.length - 1)
    cards[focused]?.scrollIntoView()
  }

  function typing(target: EventTarget | null) {
    return (
      target instanceof HTMLElement &&
      (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName))
    )
  }

  function onKeydown(event: KeyboardEvent) {
    const mod = event.metaKey || event.ctrlKey
    if (mod && !event.shiftKey && !event.altKey) {
      const key = event.key.toLowerCase()
      if (key === 'enter' && props.can.decide)
        return (event.preventDefault(), decide(draft.needs_fix ? 'check_back' : 'approved'))
      return
    }
    if (event.key === 'Escape' && typing(event.target)) return (event.target as HTMLElement).blur()
    if (typing(event.target) || event.altKey || mod) return
    const key = event.key
    if (key === 'j') return (event.preventDefault(), move(1))
    if (key === 'k') return (event.preventDefault(), move(-1))
    if (key === 'n') return (filter = filter === 'new' ? 'all' : 'new')
    if (key === 'm') return (event.preventDefault(), cards[focused]?.editNote())
    if (key === 'f') return (event.preventDefault(), decision?.focusFeedback())
    if (key === 'c' && props.can.decide) return (draft.needs_fix = !draft.needs_fix)
    if (key === '*') return topBar?.toggleStar()
    if (key === '?') return (helpOpen = !helpOpen)
    if (key === 'e') return router.visit(journalReviewRoot().url)
    if (key === 's' && props.status.due_since) return topBar?.skip()
  }

  const SHORTCUTS = [
    ['J / K', 'Next or previous journal'],
    ['N', 'Only journals new since the last review'],
    ['M', 'Note on the journal in focus'],
    ['*', 'Star or unstar'],
    ['S', 'Skip to the next project'],
    ['E', 'End the session'],
    ['F', 'Write feedback'],
    ['C', 'Tick or untick “Check back next journal”'],
    ['Ctrl/⌘ Enter', 'Give feedback'],
  ]
</script>

<svelte:window onkeydown={onKeydown} />
<svelte:head><title>{props.project.title} · Journal review</title></svelte:head>

<div class="flex h-screen flex-col overflow-hidden">
  <TopBar bind:this={topBar} page={props} />

  {#if lost}
    <div class="bg-red-600 px-4 py-1.5 text-center text-sm text-white">
      You no longer hold this project. Reload to see who does before deciding.
    </div>
  {/if}

  <div class="flex min-h-0 flex-1">
    <main class="min-w-0 flex-1 overflow-y-auto">
      <div
        class="sticky top-0 z-10 flex flex-wrap items-center gap-2 border-b border-border bg-background/95 px-4 py-2 backdrop-blur"
      >
        <span class="text-sm">
          <span class="font-semibold">{props.journals.length}</span> journals,
          <span class="font-mono">{formatMinutes(props.status.logged_minutes)}</span> logged
          {#if props.status.last_reviewed_at}
            · <span class="font-semibold">{newCount}</span> new since the last review (<span class="font-mono"
              >{formatMinutes(newMinutes)}</span
            >)
          {/if}
        </span>
        {#if props.status.last_reviewed_at}
          <div class="ml-auto">
            <Segmented
              label="Show"
              value={filter}
              onChange={(value) => (filter = value)}
              options={[
                { value: 'all', label: 'All', tint: 'gray' },
                { value: 'new', label: 'New', count: newCount, tint: 'blue' },
              ]}
            />
          </div>
        {/if}
      </div>

      <div class="space-y-3 p-4">
        {#if shown.length === 0}
          <p class="text-sm text-muted-foreground">No journals to show.</p>
        {/if}
        {#each shown as { journal, index } (journal.id)}
          <JournalCard
            bind:this={cards[index]}
            {journal}
            {index}
            fresh={fresh(journal.created_at)}
            focused={index === focused}
            onFocus={() => (focused = index)}
            bind:note={
              () => draft.journal_notes[journal.id] ?? '',
              (value) => (draft.journal_notes[journal.id] = value)
            }
            earlier={earlierNotes[journal.id] ?? []}
            editable={props.can.decide}
            maxNote={props.max_journal_note}
          />
        {/each}
        <p class="pt-2 text-center text-xs text-muted-foreground">
          <span class="font-mono">J</span>/<span class="font-mono">K</span> move between journals,
          <span class="font-mono">?</span> for every shortcut.
        </p>
      </div>
    </main>
    <ResizeHandle
      bind:width={asideWidth}
      min={ASIDE_MIN}
      max={ASIDE_MAX}
      initial={ASIDE_DEFAULT}
      storageKey="fallen:journal-review:aside-width"
    />
    <aside class="shrink-0 overflow-y-auto" style:width="{asideWidth}px">
      <DecisionPanel
        bind:this={decision}
        page={props}
        bind:feedback={draft.feedback}
        bind:needsFix={draft.needs_fix}
        journalNotes={noted}
        {submitting}
        {pending}
        {errors}
        onDecide={decide}
      />
    </aside>
  </div>
</div>

<Lightbox />

<Dialog.Root bind:open={helpOpen}>
  <Dialog.Content class="max-w-sm">
    <Dialog.Header><Dialog.Title>Shortcuts</Dialog.Title></Dialog.Header>
    <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-sm">
      {#each SHORTCUTS as [keys, what] (keys)}
        <dt><Key>{keys}</Key></dt>
        <dd class="text-muted-foreground">{what}</dd>
      {/each}
    </dl>
  </Dialog.Content>
</Dialog.Root>
