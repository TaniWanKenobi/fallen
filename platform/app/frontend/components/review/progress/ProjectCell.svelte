<script lang="ts">
  import Star from '@lucide/svelte/icons/star'
  import Link from '@/components/Link.svelte'
  import { journalReviewProject } from '@/routes'

  // A project's name in the journal review tables, linking to its review page, with its star and AI flag.
  let {
    id,
    title,
    starred = false,
    flagged = false,
  }: { id: string; title: string; starred?: boolean; flagged?: boolean } = $props()
</script>

<Link href={journalReviewProject(id)} class="group flex items-center gap-2">
  <span class="font-medium group-hover:underline">{title}</span>
  {#if starred}
    <Star class="size-3.5 fill-amber-400 text-amber-400" aria-label="Starred" />
  {/if}
  {#if flagged}
    <span
      class="rounded bg-red-100 px-1.5 py-0.5 text-[10px] font-medium text-red-700 dark:bg-red-950 dark:text-red-400"
      >AI flag</span
    >
  {/if}
</Link>
