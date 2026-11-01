// Vite resolves a dynamic import to undefined once the vite:preloadError listener in inertia.ts has cancelled its
// error to reload for a chunk a deploy removed. Wait on that reload instead of handing undefined to the caller.
export const untilReload = () => new Promise<never>(() => {})

export const chunk = <T>(module: Promise<T>): Promise<T> => module.then((loaded) => loaded ?? untilReload())
