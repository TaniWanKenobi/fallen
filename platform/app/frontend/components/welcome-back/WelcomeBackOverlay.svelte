<script module lang="ts">
  // Once answered it stays shut, even before the server's answer to that arrives.
  let done = false
</script>

<script lang="ts">
  import { onMount } from 'svelte'
  import { fade } from 'svelte/transition'
  import { router } from '@inertiajs/svelte'
  import { chunk } from '@/lib/chunks'
  import { shared } from '@/lib/shared.svelte'
  import { tour } from '@/lib/tour.svelte'
  import { welcomeBack } from '@/routes'
  import type { Answers } from './WelcomeBack.svelte'

  // The welcome back over the dashboard, after the onboarding and Slack (ApplicationController#setup_props). The
  // dialog is imported only when it's due. Whether the ping is on already comes from the page (HomeController#reminder),
  // which keeps the query out of the props every page gets.
  let { reminderOn }: { reminderOn: boolean } = $props()

  const user = $derived(shared().auth.user)
  const setup = $derived(shared().setup)
  let open = $state(false)

  onMount(() => {
    open = !done && setup?.step === 'welcome_back' && !!user?.pet && !tour.open
  })

  const load = () => chunk(import('./WelcomeBack.svelte'))
  // The scene's own exit runs for 0.25s; let it finish before the overlay fades.
  const SCENE_EXIT_MS = 250

  function close(answers: Answers) {
    done = true
    router.post(
      welcomeBack(),
      { ...answers },
      { preserveScroll: true, preserveState: true, only: ['setup', 'reminder', 'flash'] },
    )
    setTimeout(() => (open = false), SCENE_EXIT_MS)
  }

  function portal(node: HTMLElement) {
    document.body.appendChild(node)
    return () => node.remove()
  }
</script>

{#if open && setup?.step === 'welcome_back' && user?.pet}
  <div
    class={[
      'fixed inset-0 z-50 transition-colors duration-300',
      tour.spotlight ? 'pointer-events-none bg-transparent' : 'bg-black/45',
    ]}
    transition:fade={{ duration: 200 }}
    {@attach portal}
  >
    {#await load() then { default: WelcomeBack }}
      <WelcomeBack
        name={user.display_name.split(' ')[0]}
        pet={user.pet}
        form={user.pet_form}
        pronouns={setup.pronouns}
        remindable={setup.remindable}
        {reminderOn}
        hoursLeft={setup.hours_left}
        onclose={close}
      />
    {/await}
  </div>
{/if}
