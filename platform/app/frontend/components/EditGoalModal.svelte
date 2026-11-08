<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Modal from '@/components/Modal.svelte'
  import { formatMinutes } from '@/lib/format'
  import { dailyGoals } from '@/routes'

  // Setting their own minutes a day in place of the suggested goal (DailyGoalsController), or going back to it.
  let {
    current,
    suggested,
    range,
    onClose,
  }: { current: number; suggested: number; range: [number, number]; onClose: () => void } = $props()

  // The suggested goal can be outside the range a person can set (near the deadline, with a lot left), so the
  // inputs start at the nearest goal they can save.
  // svelte-ignore state_referenced_locally
  const start = Math.min(Math.max(current, range[0]), range[1])
  let hours = $state(Math.floor(start / 60))
  let mins = $state(start % 60)
  let saving = $state(false)
  let error = $state<string>()

  const total = $derived(Math.round((Number(hours) || 0) * 60 + (Number(mins) || 0)))
  const valid = $derived(total >= range[0] && total <= range[1])

  const options = () => ({
    preserveScroll: true,
    only: ['goal', 'flash'],
    onSuccess: onClose,
    // DailyGoalsController sends a refusal as errors, so the modal stays open with what they typed.
    onError: (errors: Record<string, string>) =>
      (error = errors.daily_goal_minutes ?? 'That goal could not be saved.'),
    onFinish: () => (saving = false),
  })

  function save(event: SubmitEvent) {
    event.preventDefault()
    if (!valid) return
    error = undefined
    saving = true
    router.visit(dailyGoals.update(), { data: { minutes: total }, ...options() })
  }

  function reset() {
    saving = true
    router.visit(dailyGoals.destroy(), options())
  }
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && onClose()} />

<Modal titleId="edit-goal-title" title="Your daily goal" {onClose} class="max-w-md">
  <form class="px-5 pt-2 pb-6 font-outfit md:px-9 md:pb-8" onsubmit={save}>
    <p class="text-sm text-ink">
      How long do you want to work on your project each day? The suggested goal, {formatMinutes(suggested)},
      gets your pet to its final form in time.
    </p>

    <div class="mt-5 flex items-end gap-3">
      <label class="flex-1">
        <span class="text-xs font-semibold text-ink-soft">Hours</span>
        <input
          type="number"
          min="0"
          max={Math.floor(range[1] / 60)}
          bind:value={hours}
          class="mt-1 w-full rounded-xl border-2 border-ink/15 bg-white px-3 py-2 text-lg text-ink focus:border-ink/40 focus:outline-none"
        />
      </label>
      <label class="flex-1">
        <span class="text-xs font-semibold text-ink-soft">Minutes</span>
        <input
          type="number"
          min="0"
          max="59"
          bind:value={mins}
          class="mt-1 w-full rounded-xl border-2 border-ink/15 bg-white px-3 py-2 text-lg text-ink focus:border-ink/40 focus:outline-none"
        />
      </label>
    </div>
    {#if !valid}
      <p class="mt-2 text-sm text-red-700">
        Pick between {formatMinutes(range[0])} and {formatMinutes(range[1])}.
      </p>
    {:else if error}
      <p class="mt-2 text-sm text-red-700">Minutes {error}.</p>
    {/if}

    <div class="mt-6 flex flex-wrap items-center justify-between gap-3">
      <button
        type="button"
        class="text-sm font-semibold text-ink-soft underline-offset-4 hover:underline"
        disabled={saving}
        onclick={reset}>Use the suggested goal</button
      >
      <button type="submit" class="game-btn game-btn-blue min-h-10 px-5" disabled={!valid || saving}
        >{saving ? 'Saving...' : 'Save'}</button
      >
    </div>
  </form>
</Modal>
