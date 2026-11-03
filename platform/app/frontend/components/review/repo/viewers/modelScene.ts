import * as THREE from 'three'
import { OrbitControls } from 'three/addons/controls/OrbitControls.js'

// The lit scene every 3D kind (meshes and STEP) is shown in. Fallout builds it with react-three-fiber and drei
// (<Canvas>, <Bounds fit clip observe margin={1.3}>, <Center>, <Grid infiniteGrid>, <OrbitControls>); this is the
// same scene in plain three.js: the camera starts at (3, 2.5, 3) and glides in to fit the part, the grid is drei's
// shader, and the renderer uses fiber's defaults (ACES tone mapping, sRGB, pixel ratio up to 2).

export const PART_MATERIAL = new THREE.MeshStandardMaterial({
  color: 0xb8b8c0,
  metalness: 0.1,
  roughness: 0.55,
})

const MARGIN = 1.3
const FIT_SECONDS = 1

// drei's <Grid> material (cellSize 0.5, sectionSize 1, cellThickness 0.5, sectionThickness 1, fadeStrength 1).
function gridMaterial(cellColor: string, sectionColor: string, fadeDistance: number) {
  return new THREE.ShaderMaterial({
    transparent: true,
    side: THREE.BackSide,
    uniforms: {
      cellSize: { value: 0.5 },
      sectionSize: { value: 1 },
      fadeDistance: { value: fadeDistance },
      fadeStrength: { value: 1 },
      fadeFrom: { value: 1 },
      cellThickness: { value: 0.5 },
      sectionThickness: { value: 1 },
      cellColor: { value: new THREE.Color(cellColor) },
      sectionColor: { value: new THREE.Color(sectionColor) },
      infiniteGrid: { value: true },
      followCamera: { value: false },
      worldCamProjPosition: { value: new THREE.Vector3() },
      worldPlanePosition: { value: new THREE.Vector3() },
    },
    vertexShader: /* glsl */ `
      varying vec3 localPosition;
      varying vec4 worldPosition;
      uniform vec3 worldCamProjPosition;
      uniform vec3 worldPlanePosition;
      uniform float fadeDistance;
      uniform bool infiniteGrid;
      uniform bool followCamera;
      void main() {
        localPosition = position.xzy;
        if (infiniteGrid) localPosition *= 1.0 + fadeDistance;
        worldPosition = modelMatrix * vec4(localPosition, 1.0);
        if (followCamera) {
          worldPosition.xyz += (worldCamProjPosition - worldPlanePosition);
          localPosition = (inverse(modelMatrix) * worldPosition).xyz;
        }
        gl_Position = projectionMatrix * viewMatrix * worldPosition;
      }
    `,
    fragmentShader: /* glsl */ `
      varying vec3 localPosition;
      varying vec4 worldPosition;
      uniform vec3 worldCamProjPosition;
      uniform float cellSize;
      uniform float sectionSize;
      uniform vec3 cellColor;
      uniform vec3 sectionColor;
      uniform float fadeDistance;
      uniform float fadeStrength;
      uniform float fadeFrom;
      uniform float cellThickness;
      uniform float sectionThickness;
      float getGrid(float size, float thickness) {
        vec2 r = localPosition.xz / size;
        vec2 grid = abs(fract(r - 0.5) - 0.5) / fwidth(r);
        float line = min(grid.x, grid.y) + 1.0 - thickness;
        return 1.0 - min(line, 1.0);
      }
      void main() {
        float g1 = getGrid(cellSize, cellThickness);
        float g2 = getGrid(sectionSize, sectionThickness);
        vec3 from = worldCamProjPosition * vec3(fadeFrom);
        float dist = distance(from, worldPosition.xyz);
        float d = 1.0 - min(dist / fadeDistance, 1.0);
        vec3 color = mix(cellColor, sectionColor, min(1.0, sectionThickness * g2));
        gl_FragColor = vec4(color, (g1 + g2) * pow(d, fadeStrength));
        gl_FragColor.a = mix(0.75 * gl_FragColor.a, gl_FragColor.a, g2);
        if (gl_FragColor.a <= 0.0) discard;
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }
    `,
  })
}

// drei's Bounds easing.
const ease = (t: number) => 1 - Math.exp(-5 * t) + 0.007 * t

export function mountModelScene(container: HTMLElement, object: THREE.Object3D, dark: boolean): () => void {
  // preserveDrawingBuffer lets reviewers right-click to copy or save the rendered view.
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true })
  renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1))
  renderer.toneMapping = THREE.ACESFilmicToneMapping
  renderer.outputColorSpace = THREE.SRGBColorSpace
  renderer.domElement.style.display = 'block'
  renderer.domElement.style.width = '100%'
  renderer.domElement.style.height = '100%'
  container.appendChild(renderer.domElement)

  const scene = new THREE.Scene()
  scene.background = new THREE.Color(dark ? '#18181b' : '#f4f4f5')
  scene.add(new THREE.AmbientLight(0xffffff, 0.7))
  const key = new THREE.DirectionalLight(0xffffff, 1.1)
  key.position.set(5, 8, 5)
  const fill = new THREE.DirectionalLight(0xffffff, 0.4)
  fill.position.set(-5, 3, -5)
  scene.add(key, fill)

  // <Center>: the part's bounding box centred on the origin.
  const centered = new THREE.Group()
  centered.add(object)
  object.updateWorldMatrix(true, true)
  const box = new THREE.Box3().setFromObject(object)
  if (!box.isEmpty()) object.position.sub(box.getCenter(new THREE.Vector3()))
  scene.add(centered)

  const grid = new THREE.Mesh(
    new THREE.PlaneGeometry(),
    gridMaterial(dark ? '#3f3f46' : '#d4d4d8', dark ? '#52525b' : '#a1a1aa', 40),
  )
  grid.frustumCulled = false
  grid.position.y = -0.001
  scene.add(grid)

  const camera = new THREE.PerspectiveCamera(45, 1, 0.1, 1000)
  camera.position.set(3, 2.5, 3)
  const controls = new OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.dampingFactor = 0.08

  // <Bounds fit clip>: glide from where the camera is to the distance that fits the part, along the same line.
  let from: THREE.Vector3 | null = null
  let goal: THREE.Vector3 | null = null
  let t = 0
  function fit() {
    centered.updateWorldMatrix(true, true)
    const bounds = new THREE.Box3().setFromObject(centered)
    if (bounds.isEmpty()) bounds.setFromCenterAndSize(new THREE.Vector3(), new THREE.Vector3(10, 10, 10))
    const size = bounds.getSize(new THREE.Vector3())
    const center = bounds.getCenter(new THREE.Vector3())
    const maxSize = Math.max(size.x, size.y, size.z)
    const fitHeight = maxSize / (2 * Math.atan((Math.PI * camera.fov) / 360))
    const distance = MARGIN * Math.max(fitHeight, fitHeight / camera.aspect)
    const direction = camera.position.clone().sub(center).normalize()
    from = camera.position.clone()
    goal = center.clone().addScaledVector(direction, distance)
    controls.target.copy(center)
    t = 0
    camera.near = distance / 100
    camera.far = distance * 100
    camera.updateProjectionMatrix()
    controls.maxDistance = distance * 10
  }
  controls.addEventListener('start', () => (goal = null))

  const plane = new THREE.Plane()
  const up = new THREE.Vector3(0, 1, 0)
  const timer = new THREE.Timer()
  let frame = 0
  function tick() {
    frame = requestAnimationFrame(tick)
    timer.update()
    const delta = timer.getDelta()
    if (goal && from) {
      t = Math.min(1, t + delta / FIT_SECONDS)
      camera.position.lerpVectors(from, goal, Math.min(1, ease(t)))
      if (t >= 1) goal = null
    }
    controls.update()
    const material = grid.material as THREE.ShaderMaterial
    plane.setFromNormalAndCoplanarPoint(up, new THREE.Vector3()).applyMatrix4(grid.matrixWorld)
    plane.projectPoint(camera.position, material.uniforms.worldCamProjPosition.value)
    material.uniforms.worldPlanePosition.value.set(0, 0, 0).applyMatrix4(grid.matrixWorld)
    renderer.render(scene, camera)
  }

  // observe: fit again when the panel changes size.
  const resize = () => {
    const width = container.clientWidth || 1
    const height = container.clientHeight || 1
    renderer.setSize(width, height, false)
    camera.aspect = width / height
    camera.updateProjectionMatrix()
    fit()
  }
  const observer = new ResizeObserver(resize)
  observer.observe(container)
  resize()
  tick()

  return () => {
    cancelAnimationFrame(frame)
    observer.disconnect()
    controls.dispose()
    renderer.dispose()
    renderer.domElement.remove()
    scene.traverse((node) => {
      if (node instanceof THREE.Mesh) {
        node.geometry.dispose()
        if (node.material !== PART_MATERIAL) (node.material as THREE.Material).dispose()
      }
    })
  }
}

// The scene as a Svelte action: `use:modelScene={[object, dark]}`.
export function modelScene(node: HTMLElement, [object, dark]: [THREE.Object3D, boolean]) {
  let destroy = mountModelScene(node, object, dark)
  return {
    update([next, nextDark]: [THREE.Object3D, boolean]) {
      destroy()
      destroy = mountModelScene(node, next, nextDark)
    },
    destroy: () => destroy(),
  }
}
