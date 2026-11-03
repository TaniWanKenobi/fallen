<script lang="ts">
  import { FileTree } from '@pierre/trees'
  import { REPO_TREE_ICONS } from './treeIcons'

  // Fallout's repo tree: @pierre/trees (its framework-free core, which Fallout reaches through the React wrapper),
  // with search, sticky folders and our hardware file icons. Density is fixed when a tree is made, so the Pinned view
  // has its own relaxed tree: the same folders with everything but the files a reviewer judges taken out.
  let {
    paths,
    pinnedPaths,
    pinned,
    selected,
    dark,
    onSelect,
  }: {
    paths: string[]
    pinnedPaths: string[]
    pinned: boolean
    selected: string | null
    dark: boolean
    onSelect: (path: string) => void
  } = $props()

  // svelte-ignore state_referenced_locally
  const files = new Set(paths)
  const options = {
    icons: REPO_TREE_ICONS,
    initialExpansion: 1,
    search: true,
    flattenEmptyDirectories: true,
    stickyFolders: true,
    onSelectionChange: (selection: readonly string[]) => {
      const path = selection[0]
      if (path && path !== selected && files.has(path)) onSelect(path)
    },
  } as const
  // svelte-ignore state_referenced_locally
  const all = new FileTree({ ...options, paths, density: 'compact' })
  // svelte-ignore state_referenced_locally
  const pinnedTree = new FileTree({ ...options, paths: pinnedPaths, density: 'relaxed' })
  const model = $derived(pinned ? pinnedTree : all)

  $effect(() => () => {
    all.cleanUp()
    pinnedTree.cleanUp()
  })

  $effect(() => {
    if (selected) model.getItem(selected)?.select()
  })

  function mount(node: HTMLElement, tree: FileTree) {
    tree.render({ fileTreeContainer: node })
    if (selected) tree.getItem(selected)?.select()
    return { destroy: () => tree.unmount() }
  }
</script>

<!-- @pierre/trees paints with light-dark(), so it follows color-scheme rather than our .dark class. -->
{#key model}
  <file-tree-container
    use:mount={model}
    class="block min-h-0 flex-1"
    style:color-scheme={dark ? 'dark' : 'light'}
    style:--trees-item-height="{model.getItemHeight()}px"
    style:--trees-density-override={model.getDensityFactor()}
    style:--trees-padding-inline-override="6px"
    style:--trees-bg-override="transparent"
    style:--trees-bg-muted-override="var(--muted)"
    style:--trees-fg-override="var(--foreground)"
    style:--trees-fg-muted-override="var(--muted-foreground)"
    style:--trees-border-color-override="var(--border)"
    style:--trees-accent-override="var(--foreground)"
  ></file-tree-container>
{/key}
