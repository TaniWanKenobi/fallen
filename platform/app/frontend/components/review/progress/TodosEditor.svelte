<script lang="ts">
  import Plus from '@lucide/svelte/icons/plus'
  import RotateCcw from '@lucide/svelte/icons/rotate-ccw'
  import X from '@lucide/svelte/icons/x'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import type { ProgressPage } from '@/lib/progressReview'

  // What a check back asks the team to fix. Earlier ones still open are listed with whether the team ticked them; a
  // ticked one that isn't really fixed can be reopened. New ones are typed here, one per line. Approving resolves all.
  let {
    page,
    todos = $bindable(),
    reopen = $bindable(),
  }: { page: ProgressPage; todos: string[]; reopen: string[] } = $props()

  const share = $derived(Math.round(page.xp_held_share * 100))

  function toggleReopen(id: string) {
    reopen = reopen.includes(id) ? reopen.filter((r) => r !== id) : [...reopen, id]
  }
</script>

<div class="space-y-2">
  <p class="text-xs text-muted-foreground">
    To fix <span class="text-muted-foreground/60"
      >(for a check back: only the team sees these, in their DMs and on their project page)</span
    >
  </p>

  {#if page.todos.length}
    <ul class="space-y-1.5">
      {#each page.todos as todo (todo.id)}
        {@const reopened = reopen.includes(todo.id)}
        <li class="rounded-md border border-border px-2 py-1.5 text-[13px]">
          <p class={todo.done && !reopened ? 'text-muted-foreground line-through' : ''}>{todo.body}</p>
          <div class="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-muted-foreground">
            {#if todo.done && !reopened}
              <span class="text-emerald-700 dark:text-emerald-400">Ticked off</span>
              {#if todo.done_by}by <PersonChip person={todo.done_by} />{/if}
              <button
                type="button"
                onclick={() => toggleReopen(todo.id)}
                class="ml-auto flex items-center gap-1 hover:text-foreground"
                ><RotateCcw class="size-3" /> Not fixed</button
              >
            {:else if reopened}
              <span class="text-amber-700 dark:text-amber-400">Reopened by you</span>
              <button
                type="button"
                onclick={() => toggleReopen(todo.id)}
                class="ml-auto hover:text-foreground">Undo</button
              >
            {:else}
              <span>Not ticked yet</span>
            {/if}
          </div>
        </li>
      {/each}
    </ul>
  {/if}

  {#each todos as _, i (i)}
    <div class="flex items-center gap-1">
      <input
        bind:value={todos[i]}
        maxlength={page.max_todo}
        placeholder="e.g. Add a photo of the wiring to each journal"
        class="h-8 min-w-0 flex-1 rounded-md border border-input bg-background px-2.5 text-sm outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
      />
      <button
        type="button"
        aria-label="Remove"
        onclick={() => (todos = todos.filter((__, n) => n !== i))}
        class="grid size-8 place-items-center rounded-md text-muted-foreground hover:bg-muted hover:text-foreground"
        ><X class="size-3.5" /></button
      >
    </div>
  {/each}
  <button
    type="button"
    onclick={() => (todos = [...todos, ''])}
    class="flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
    ><Plus class="size-3.5" /> Add something to fix</button
  >

  <p class="text-xs text-muted-foreground">
    {#if page.project.submitted}
      It's been submitted, so a check back holds no XP.
    {:else if page.check_back_holds}
      The last review was a check back too, so this one holds back {share}% of the XP their journals earned
      since then until a reviewer sees these fixed.
    {:else}
      A first check back only warns them; a second in a row holds back {share}% of their new journals' XP
      until these are fixed.
    {/if}
    {#if page.held_xp > 0}
      <span class="font-medium text-foreground">{page.held_xp} XP is held now;</span> approving gives it back.
    {/if}
  </p>
</div>
