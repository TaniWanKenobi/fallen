<script lang="ts">
  import * as Card from '@/components/admin/ui/card'

  // A card's title and description, with a legend for its chart's series.
  let {
    title,
    description,
    series = [],
  }: { title: string; description: string; series?: { label: string; color: string }[] } = $props()
</script>

<Card.Header class="flex flex-wrap items-start gap-x-4 gap-y-1">
  <div class="flex-1">
    <Card.Title>{title}</Card.Title>
    <Card.Description>{description}</Card.Description>
  </div>
  <div class="flex flex-wrap gap-x-4 gap-y-1">
    {#each series as item (item.label)}
      <span class="flex items-center gap-1.5 text-xs text-muted-foreground">
        <span class="size-2 rounded-[2px]" style="background: {item.color}"></span>{item.label}
      </span>
    {/each}
  </div>
</Card.Header>
