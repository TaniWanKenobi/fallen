<script lang="ts">
  import LoaderCircle from '@lucide/svelte/icons/loader'

  let { label }: { label?: string } = $props()
</script>

<div class="flex h-full flex-col items-center justify-center gap-2 text-muted-foreground">
  <LoaderCircle class="size-5 animate-spin" />
  {#if label}<p class="text-xs">{label}</p>{/if}
</div>
