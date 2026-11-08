<script lang="ts">
  // The top of the dashboard: how far the person is from the XP for their pet's final form (Evolution::STAGE_XP),
  // with the last seven days' XP drawn as the brighter end of the bar.
  // It shimmers until the pointer first goes over it (a tap, on a touchscreen), which this browser remembers.
  // With the days left until the deadline (DailyGoal::DEADLINE).
  let {
    total,
    goal,
    lastWeek,
    deadline,
    daysLeft,
  }: { total: number; goal: number; lastWeek: number; deadline: string; daysLeft: number } = $props()

  const deadlineDay = $derived(
    new Intl.DateTimeFormat(undefined, {
      month: 'short',
      day: 'numeric',
      timeZone: 'America/New_York',
    }).format(new Date(deadline)),
  )

  const SEEN = 'fallen:xp-goal-bar-seen'
  let shining = $state(false)

  $effect(() => {
    try {
      shining = localStorage.getItem(SEEN) !== '1'
    } catch {
      shining = true
    }
  })

  function stopShining() {
    shining = false
    try {
      localStorage.setItem(SEEN, '1')
    } catch {
      // Private windows: it shimmers again next visit.
    }
  }

  const share = (xp: number) => Math.min(Math.max(xp / goal, 0), 1) * 100
  const before = $derived(share(total - lastWeek))
  const week = $derived(share(total) - before)
  const left = $derived(Math.max(goal - total, 0))
</script>

<!-- This only stops a decoration, so it needs no keyboard equivalent. -->
<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<section
  class="glass setting-row relative overflow-hidden font-outfit"
  aria-label="Your way to {goal} XP"
  onpointerenter={shining ? stopShining : undefined}
>
  {#if shining}
    <div class="xp-shine pointer-events-none absolute inset-0" aria-hidden="true"></div>
  {/if}
  <div class="w-full">
    <div class="flex flex-wrap items-end justify-between gap-x-4 gap-y-1">
      <p class="font-montserrat text-lg font-semibold tracking-[-0.02em] text-white">
        {#if left > 0}
          {left} XP to go
        {:else}
          {goal} XP reached!
        {/if}
        <span class="ml-1 text-sm font-semibold text-cream/70 tabular-nums">{total} / {goal}</span>
      </p>
      <p class="font-montserrat text-sm font-semibold text-cream/70">
        <span class="text-cream">+{lastWeek} XP</span> in the last 7 days ·
        {#if daysLeft > 0}
          <span class="text-saffron">{daysLeft}</span>
          {daysLeft === 1 ? 'day' : 'days'} left until {deadlineDay}
        {:else}
          {deadlineDay} has passed
        {/if}
      </p>
    </div>
    <div
      class="mt-3 flex h-3 overflow-hidden rounded-full bg-white/15"
      role="progressbar"
      aria-label="XP toward {goal}"
      aria-valuenow={Math.min(total, goal)}
      aria-valuemin={0}
      aria-valuemax={goal}
    >
      <div class="h-full bg-saffron/60 transition-[width] duration-700" style:width="{before}%"></div>
      <div
        class={[
          'h-full bg-saffron shadow-[0_0_12px_var(--color-saffron)] transition-[width] duration-700',
          week > 0 && 'rounded-r-full',
        ]}
        style:width="{week}%"
        title="+{lastWeek} XP in the last 7 days"
      ></div>
    </div>
  </div>
</section>

<style>
  /* A band of light that sweeps across every few seconds. */
  .xp-shine {
    background: linear-gradient(
      105deg,
      transparent 35%,
      rgb(255 255 255 / 0.18) 45%,
      rgb(255 236 190 / 0.35) 50%,
      rgb(255 255 255 / 0.18) 55%,
      transparent 65%
    );
    background-size: 250% 100%;
    animation: xp-shine 3s ease-in-out infinite;
  }
  @keyframes xp-shine {
    from {
      background-position: 150% 0;
    }
    60%,
    to {
      background-position: -50% 0;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .xp-shine {
      animation: none;
      background: rgb(255 236 190 / 0.06);
    }
  }
</style>
