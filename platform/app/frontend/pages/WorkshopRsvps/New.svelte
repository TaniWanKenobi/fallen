<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import { useForm } from '@inertiajs/svelte'
  import Link from '@/components/Link.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { home, root, workshopRsvp } from '@/routes'
  import { shared } from '@/lib/shared.svelte'
  import sky from '@/assets/hero/starry-bg.webp'

  type Slot = { key: string; starts_at: string; ends_at: string }

  // The workshop sign-up, linked only from the invite email (WorkshopRsvpsController). Times are shown in the
  // visitor's own timezone, named, since the email gives them in Eastern.
  let {
    title,
    slots,
    signed_up,
    email,
  }: { title: string; slots: Slot[]; signed_up: string | null; email: string | null } = $props()

  const day = new Intl.DateTimeFormat(undefined, { weekday: 'long', month: 'long', day: 'numeric' })
  const time = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' })
  const zoneName = $derived(
    new Intl.DateTimeFormat(undefined, { timeZoneName: 'short' })
      .formatToParts(new Date(slots[0]?.starts_at ?? Date.now()))
      .find((part) => part.type === 'timeZoneName')?.value,
  )

  function label(slot: Slot) {
    const start = new Date(slot.starts_at)
    return `${day.format(start)}, ${time.formatRange(start, new Date(slot.ends_at))}`
  }

  // svelte-ignore state_referenced_locally
  const form = useForm({ email: email ?? '', slack_username: '', slot: signed_up ?? slots[0]?.key ?? '' })
  const picked = $derived(slots.find((slot) => slot.key === signed_up))
  // The logo goes to the Fallen site, or to the dashboard for someone already signed in.
  const logoHref = $derived(shared().auth.user ? home.index() : root())

  function submit(event: SubmitEvent) {
    event.preventDefault()
    form.transform((data) => ({ workshop_rsvp: data })).post(workshopRsvp().url)
  }
</script>

<svelte:head><title>{title} · Fallen</title></svelte:head>

<div class="relative min-h-screen overflow-x-clip bg-sky-deep text-white">
  <img
    src={sky}
    alt=""
    aria-hidden="true"
    class="pointer-events-none fixed inset-0 h-full w-full object-cover"
  />

  <Link href={logoHref} aria-label="Fallen" class="absolute top-4 left-4 z-10 sm:top-6 sm:left-6">
    <Wordmark onDark class="h-12 sm:h-14" />
  </Link>

  <div class="relative mx-auto flex min-h-screen max-w-lg flex-col justify-center px-4 pt-24 pb-10 sm:py-10">
    <section class="sky-card">
      <h1 class="mt-1 text-2xl text-gold font-lora font-bold">{title}</h1>

      {#if picked}
        <div class="mt-5 space-y-3 font-outfit">
          <p class="text-lg text-cream">You've signed up for {label(picked)}.</p>
          <p class="text-sky-ice/80">We'll email you the link on the day of the workshop. See you!</p>
        </div>
      {:else if slots.length === 0}
        <p class="mt-3 font-outfit text-sky-ice/80">
          These workshops have all started, so sign-ups are closed. Thanks for stopping by!
        </p>
      {:else}
        <div class="mt-3 space-y-3 font-outfit text-sky-ice/80">
          <p>
            We're running hardware workshops this month! You'll make your own Tamagotchi pet (for free), and
            you don't need any hardware experience.
          </p>
          <p>Pick a time and we'll email you the Zoom link on the day of the workshop!</p>
          <p>See you there :) <br /> ~Sophia</p>
        </div>

        <form class="mt-6 space-y-5 font-outfit" onsubmit={submit}>
          <label class="block">
            <span class="sky-label">Email</span>
            <input
              type="email"
              required
              autocomplete="email"
              bind:value={form.email}
              class="mt-1 w-full rounded-lg border border-white/15 bg-white/5 px-3 py-2 text-white placeholder:text-sky-ice/40 focus:border-sky-gold focus:ring-0"
              placeholder="you@workshop.soon"
            />
            {#if form.errors.email}<span class="mt-1 block text-sm text-hc-red">{form.errors.email}</span
              >{/if}
          </label>

          <label class="block">
            <span class="sky-label">Slack username <span class="text-sky-ice/40">(optional)</span></span>
            <input
              type="text"
              autocomplete="off"
              maxlength="80"
              bind:value={form.slack_username}
              class="mt-1 w-full rounded-lg border border-white/15 bg-white/5 px-3 py-2 text-white placeholder:text-sky-ice/40 focus:border-sky-gold focus:ring-0"
              placeholder="@username"
            />
            {#if form.errors.slack_username}
              <span class="mt-1 block text-sm text-hc-red">{form.errors.slack_username}</span>
            {/if}
          </label>

          <label class="block">
            <span class="sky-label">Workshop time</span>
            <select
              required
              bind:value={form.slot}
              class="mt-1 w-full rounded-lg border border-white/15 bg-sky-night px-3 py-2 text-white focus:border-sky-gold focus:ring-0"
            >
              {#each slots as slot (slot.key)}
                <option value={slot.key}>{label(slot)}</option>
              {/each}
            </select>
            <span class="mt-1 block text-xs text-sky-ice/55">
              In your timezone{zoneName ? ` (${zoneName})` : ''}
            </span>
            {#if form.errors.slot}<span class="mt-1 block text-sm text-hc-red">{form.errors.slot}</span>{/if}
          </label>

          <button type="submit" class="btn-sky-gold w-full" disabled={form.processing}>
            {form.processing ? 'Signing you up...' : 'Sign me up!'}
          </button>
        </form>
      {/if}
    </section>
  </div>
</div>
