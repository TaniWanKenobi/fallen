// The review page's lightbox (Lightbox.svelte): which images are open, which one is showing, and the thumbnail it
// opened from, so it can grow out of that thumbnail and shrink back into it.
export interface LightboxImage {
  url: string
  alt: string
  // The thumbnail on the page, for the open and close animation. Missing for ones it can't find.
  from?: HTMLElement
}

export const lightbox = $state<{ images: LightboxImage[]; index: number }>({ images: [], index: -1 })

export function openLightbox(images: LightboxImage[], index: number) {
  lightbox.images = images
  lightbox.index = index
}

export function closeLightbox() {
  lightbox.images = []
  lightbox.index = -1
}

// Every picture inside an element (a journal's writing) opens in the lightbox, in order, instead of a new tab.
export function lightboxImages(node: HTMLElement) {
  const click = (event: MouseEvent) => {
    const target = (event.target as HTMLElement).closest('img')
    if (!target || !node.contains(target)) return
    event.preventDefault()
    const images = [...node.querySelectorAll('img')]
    openLightbox(
      images.map((img) => ({ url: img.currentSrc || img.src, alt: img.alt, from: img })),
      images.indexOf(target),
    )
  }
  node.addEventListener('click', click)
  return () => node.removeEventListener('click', click)
}
