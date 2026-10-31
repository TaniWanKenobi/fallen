<script lang="ts">
  import { createSkeletonBox } from 'skullet'

  // A placeholder in skullet's shimmer: one diagonal highlight sweeps the whole page, and every skeleton on it shows
  // its slice of that same sweep, however late it mounts. Size and corners come from `class`, and skullet's bar fills
  // them; the colours come from --skullet-base and --skullet-highlight (application.css and admin.css).
  let { class: className = '', style }: { class?: string; style?: string } = $props()

  const fill = (node: HTMLElement) => {
    node.append(createSkeletonBox({ width: '100%', height: '100%', radius: 'inherit' }))
  }
</script>

<div {@attach fill} aria-hidden="true" class={className} {style}></div>
