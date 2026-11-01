<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Modal from '@/components/Modal.svelte'
  import * as sfx from '@/lib/sfx'
  import { journals } from '@/routes'
  import type { Journal, ProjectChoice } from '@/types'

  // Moving one of your journals to another project you're on: its hours, photos and XP go with it, and Fallen moves
  // its Slack reply to the other thread. The choices come from the page's optional `move_targets` prop.
  let {
    journal,
    targets,
    onClose,
  }: { journal: Journal; targets: ProjectChoice[] | undefined; onClose: () => void } = $props()

  let moving = $state<string | null>(null)

  $effect(() => {
    router.reload({ only: ['move_targets'], preserveUrl: true })
  })

  function move(target: ProjectChoice) {
    sfx.select()
    moving = target.id
    router.patch(
      journals.move(journal.id).url,
      { project_id: target.id },
      { preserveScroll: true, onSuccess: onClose, onFinish: () => (moving = null) },
    )
  }
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && onClose()} />

<Modal titleId="move-journal-title" title="Move journal" {onClose}>
  <div class="max-h-[calc(90vh-130px)] overflow-y-auto px-5 pt-2 pb-6 font-outfit md:px-9 md:pb-8">
    <p class="text-sm text-ink">
      Pick the project it belongs to. Its hours, photos and XP come with it, and its Slack reply moves to that
      project's thread.
    </p>

    {#if targets === undefined}
      <p class="mt-5 text-sm text-ink-soft">Loading your projects...</p>
    {:else if targets.length === 0}
      <p class="mt-5 text-sm text-ink-soft">
        There's no other project to move it to. Journals can't move into or out of an approved project.
      </p>
    {:else}
      <ul class="mt-4 space-y-1">
        {#each targets as target (target.id)}
          <li class="flex items-center gap-3 rounded-xl px-2 py-1.5 hover:bg-ink/5">
            <span class="min-w-0 flex-1 truncate font-semibold text-ink">{target.title}</span>
            <button
              type="button"
              class="game-btn game-btn-blue min-h-9 px-4 text-sm"
              disabled={moving !== null}
              onclick={() => move(target)}>{moving === target.id ? 'Moving...' : 'Move here'}</button
            >
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</Modal>
