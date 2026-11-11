<script lang="ts">
  // One series in a chart's tooltip: its swatch and name, then its value, or a dash where it has none.
  let {
    name,
    color,
    value,
    format,
  }: {
    name: string
    color?: string
    value: unknown
    format: (value: number) => string
  } = $props()
</script>

<div class="flex w-full items-center justify-between gap-4">
  <span class="flex items-center gap-1.5 text-muted-foreground">
    <span class="size-2 rounded-[2px]" style="background: {color}"></span>{name}
  </span>
  <span class="font-mono font-medium tabular-nums">{value == null ? '—' : format(Number(value))}</span>
</div>
