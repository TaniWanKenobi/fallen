<script lang="ts">
  let { person, class: className = '' }: { person: { name: string; avatar: string }; class?: string } =
    $props()
</script>

<span class="inline-flex min-w-0 items-center gap-1.5 {className}">
  <img
    src={person.avatar}
    alt=""
    width="16"
    height="16"
    class="size-4 shrink-0 rounded-full bg-muted object-cover"
  />
  <span class="truncate">{person.name}</span>
</span>
