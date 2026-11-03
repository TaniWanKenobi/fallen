<script lang="ts">
  import type * as THREE from 'three'
  import type { RepoSource } from '@/lib/repoFetch'
  import { modelScene } from './modelScene'
  import { buildGroup, parseStep } from './stepClient'
  import Spinner from './Spinner.svelte'

  // STEP parts, tessellated with OpenCascade in a worker and shown in the same scene as other models.
  let { path, source, dark }: { path: string; source: RepoSource; dark: boolean } = $props()

  let object = $state.raw<THREE.Group | null>(null)
  let error = $state<string | null>(null)
  let stage = $state('Downloading…')

  $effect(() => {
    let cancelled = false
    source
      .buffer(path)
      .then((bytes) => {
        if (cancelled) return null
        stage = 'Tessellating with OpenCascade…'
        return parseStep(bytes.slice(0))
      })
      .then((meshes) => {
        if (cancelled || !meshes) return
        if (meshes.length === 0) throw new Error('No solids found in this STEP file')
        object = buildGroup(meshes)
      })
      .catch((e: Error) => !cancelled && (error = e.message))
    return () => (cancelled = true)
  })
</script>

{#if error}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t render this STEP file ({error}).</p>
{:else if !object}
  <Spinner label={stage} />
{:else}
  <div class="h-full w-full" use:modelScene={[object, dark]}></div>
{/if}
