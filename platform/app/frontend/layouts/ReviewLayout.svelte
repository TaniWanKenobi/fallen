<script lang="ts">
  import type { Snippet } from 'svelte'
  import { BitsConfig } from 'bits-ui'
  import AdminToaster from '@/components/admin/AdminToaster.svelte'
  import { adminDark } from '@/lib/adminDark.svelte'

  // The design review queue: the admin theme, full screen, no sidebar, so the review page can use all of it.
  let { children }: { children?: Snippet } = $props()
</script>

<svelte:head><title>Fallen Review</title></svelte:head>

<div
  class={[
    'admin PortalTarget min-h-screen bg-background text-foreground antialiased',
    adminDark.on && 'dark',
  ]}
>
  <BitsConfig defaultPortalTo=".admin">
    <AdminToaster />
    {@render children?.()}
  </BitsConfig>
</div>
