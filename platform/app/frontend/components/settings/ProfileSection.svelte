<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import SettingRow from '@/components/settings/SettingRow.svelte'
  import { PRONOUNS } from '@/lib/pronouns'
  import { pronouns as pronounsRoute, signOut } from '@/routes'
  import type { User } from '@/types'

  let { user, timezone, pronouns }: { user: User; timezone?: string; pronouns?: string | null } = $props()

  let saving = $state(false)

  // Picking the one they have clears it.
  function choose(choice: string) {
    saving = true
    router.patch(
      pronounsRoute.update(),
      { pronouns: choice === pronouns ? '' : choice },
      { preserveScroll: true, only: ['pronouns', 'flash'], onFinish: () => (saving = false) },
    )
  }
</script>

<SettingRow title={user.display_name} description="Your name and picture come from your Slack profile.">
  {#snippet lead()}
    <img
      src={user.avatar}
      alt=""
      class="size-14 rounded-full object-cover ring-2 ring-cream/70 ring-offset-2 ring-offset-transparent"
    />
  {/snippet}
</SettingRow>
<SettingRow title="Pronouns">
  <div class="flex flex-wrap gap-2" role="radiogroup" aria-label="Pronouns">
    {#each PRONOUNS as choice (choice)}
      <button
        type="button"
        role="radio"
        aria-checked={pronouns === choice}
        disabled={saving}
        class={['pill-glass', pronouns === choice && 'bg-cream! text-slate-ink!']}
        onclick={() => choose(choice)}>{choice}</button
      >
    {/each}
  </div>
</SettingRow>
<SettingRow
  title="Timezone"
  description="Set from your browser. The days your journals count toward are in this timezone."
>
  <span class="font-montserrat font-semibold text-cream">{timezone ?? '…'}</span>
</SettingRow>
<SettingRow title="Sign out" description="Sign out of Fallen in this browser.">
  <button type="button" class="pill-glass" onclick={() => router.visit(signOut())}>Sign out</button>
</SettingRow>
