<script lang="ts">
  // A placeholder in skullet's shimmer: one diagonal highlight sweeps the whole page, and every skeleton on it shows
  // its slice of that same sweep, however late it mounts. Size and corners come from `class`, and skullet's bar fills
  // them; the colours come from --skullet-base and --skullet-highlight (application.css and admin.css). skullet is
  // imported here rather than bundled, since the layout's pet timer uses this and would put all of it in the entry
  // chunk; until it arrives the placeholder is the plain base colour.
  let { class: className = '', style }: { class?: string; style?: string } = $props()

  let ready = $state(false)

  const fill = (node: HTMLElement) => {
    let gone = false
    import('skullet').then(({ createSkeletonBox }) => {
      if (gone) return
      node.append(createSkeletonBox({ width: '100%', height: '100%', radius: 'inherit' }))
      ready = true
    })
    return () => {
      gone = true
    }
  }
</script>

<div
  {@attach fill}
  aria-hidden="true"
  class={className}
  {style}
  style:background-color={ready ? null : 'var(--skullet-base)'}
></div>
