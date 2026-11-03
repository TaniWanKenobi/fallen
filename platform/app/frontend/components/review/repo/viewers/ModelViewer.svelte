<script lang="ts">
  import * as THREE from 'three'
  import { STLLoader } from 'three/addons/loaders/STLLoader.js'
  import { OBJLoader } from 'three/addons/loaders/OBJLoader.js'
  import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js'
  import { PLYLoader } from 'three/addons/loaders/PLYLoader.js'
  import { ThreeMFLoader } from 'three/addons/loaders/3MFLoader.js'
  import type { RepoSource } from '@/lib/repoFetch'
  import { fileExt } from '@/lib/repoFileKinds'
  import { modelScene, PART_MATERIAL } from './modelScene'
  import Spinner from './Spinner.svelte'

  // STL, OBJ, glTF, PLY and 3MF parts (Fallout's ModelViewer).
  let { path, source, dark }: { path: string; source: RepoSource; dark: boolean } = $props()

  let object = $state.raw<THREE.Object3D | null>(null)
  let error = $state<string | null>(null)

  // A .gltf names its buffers and textures by relative path, which resolve to other files of the repo.
  async function gltfResources(text: string): Promise<Map<string, string>> {
    const dir = path.includes('/') ? path.slice(0, path.lastIndexOf('/') + 1) : ''
    const json = JSON.parse(text) as { buffers?: { uri?: string }[]; images?: { uri?: string }[] }
    const uris = [...(json.buffers ?? []), ...(json.images ?? [])]
      .map((entry) => entry.uri)
      .filter((uri): uri is string => !!uri && !/^[a-z]+:/i.test(uri))
    const urls = new Map<string, string>()
    await Promise.all(
      uris.map(async (uri) => {
        const resolved = new URL(uri, `https://repo.invalid/${dir}`).pathname.slice(1)
        const file = decodeURIComponent(resolved)
        if (source.paths.has(file)) urls.set(uri, await source.objectUrl(file))
      }),
    )
    return urls
  }

  async function load(): Promise<THREE.Object3D> {
    const bytes = await source.buffer(path)
    switch (fileExt(path)) {
      case 'stl': {
        const geometry = new STLLoader().parse(bytes)
        geometry.computeVertexNormals()
        return new THREE.Mesh(geometry, PART_MATERIAL)
      }
      case 'ply': {
        const geometry = new PLYLoader().parse(bytes)
        geometry.computeVertexNormals()
        return new THREE.Mesh(geometry, PART_MATERIAL)
      }
      case 'obj':
        return new OBJLoader().parse(new TextDecoder().decode(bytes))
      case '3mf':
        return new ThreeMFLoader().parse(bytes)
      default: {
        const manager = new THREE.LoadingManager()
        if (fileExt(path) === 'gltf') {
          const urls = await gltfResources(new TextDecoder().decode(bytes))
          manager.setURLModifier((url) => urls.get(url) ?? urls.get(decodeURIComponent(url)) ?? url)
        }
        const gltf = await new GLTFLoader(manager).parseAsync(bytes, '')
        return gltf.scene
      }
    }
  }

  $effect(() => {
    let cancelled = false
    load().then(
      (o) => !cancelled && (object = o),
      (e: Error) => !cancelled && (error = e.message || 'Failed to load model'),
    )
    return () => (cancelled = true)
  })
</script>

{#if error}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t render this model ({error}).</p>
{:else if !object}
  <Spinner />
{:else}
  <div class="h-full w-full" use:modelScene={[object, dark]}></div>
{/if}
