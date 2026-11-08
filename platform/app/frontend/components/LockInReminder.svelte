<script module lang="ts">
  // HomeController#reminder: whether the day-end ping (DayEndReminder) is on, and whether Slack can reach them.
  export interface Reminder {
    on: boolean
    available: boolean
    hours_left: number
  }
</script>

<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { dayEndReminders, settings } from '@/routes'
  import Link from '@/components/Link.svelte'

  // The "Ping me on Slack to lock in" box. The welcome back spotlights it (data-tour), the way the onboarding points
  // at the project button.
  let { reminder }: { reminder: Reminder } = $props()

  let saving = $state(false)

  function toggle(event: Event) {
    const box = event.currentTarget as HTMLInputElement
    saving = true
    router.visit(box.checked ? dayEndReminders.create() : dayEndReminders.destroy(), {
      preserveScroll: true,
      preserveState: true,
      only: ['reminder', 'flash'],
      // When the server refuses, `reminder.on` comes back unchanged and Svelte has nothing to update, so the box
      // would stay as clicked. Set it to what the server says either way.
      onFinish: () => {
        saving = false
        box.checked = reminder.on
      },
    })
  }
</script>

<label
  data-tour="lock-in-reminder"
  class={['setting-row', reminder.available ? 'cursor-pointer' : 'cursor-not-allowed opacity-70']}
>
  <input
    type="checkbox"
    class="size-6 shrink-0 cursor-[inherit] accent-saffron"
    checked={reminder.on}
    disabled={!reminder.available || saving}
    onchange={toggle}
  />
  <span class="min-w-0 flex-1 basis-56">
    <span class="block font-montserrat text-lg font-semibold tracking-[-0.02em] text-white"
      >Ping me on Slack to lock in</span
    >
    <span class="mt-0.5 block font-outfit text-sm text-sky-ice/60">
      {#if reminder.available}
        Your pet pings you in your team’s channel when your day has {reminder.hours_left} hours left and you haven’t
        journaled.
      {:else}
        <Link href={settings.show({ anchor: 'slack' })} class="underline">Connect Slack</Link> so the ping can reach
        you.
      {/if}
    </span>
  </span>
</label>
