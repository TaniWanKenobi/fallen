<script lang="ts">
  import hljs from 'highlight.js/lib/common'
  import 'highlight.js/styles/github.css'
  import type { Snippet } from 'svelte'
  import { isLfsPointer, looksBinary, type RepoSource } from '@/lib/repoFetch'
  import { codeLanguage, MAX_TEXT_BYTES } from '@/lib/repoFileKinds'
  import Lazy from '../Lazy.svelte'
  import Spinner from './Spinner.svelte'

  // Source and text files with line numbers, highlighted by highlight.js (Fallout's CodeView).
  let { path, source, fallback }: { path: string; source: RepoSource; fallback: Snippet<[string?]> } =
    $props()

  // EasyEDA (classic) exports are plain .json, so they go to the schematic and PCB renderer instead.
  const EASYEDA_JSON_SIGNATURE = /"docType"\s*:|"head"\s*:\s*\{|"shape"\s*:\s*\[/

  type Result = { kind: 'lines'; lines: string[] } | { kind: 'easyeda' } | { kind: 'note'; text: string }

  async function load(): Promise<Result> {
    const bytes = await source.buffer(path)
    if (bytes.byteLength > MAX_TEXT_BYTES)
      return { kind: 'note', text: 'This file is too large to preview inline.' }
    const text = new TextDecoder().decode(bytes)
    if (isLfsPointer(text))
      return {
        kind: 'note',
        text: 'This file is stored in Git LFS, and the repository only has the pointer.',
      }
    if (looksBinary(text)) return { kind: 'note', text: 'This looks like a binary file.' }
    const lang = codeLanguage(path)
    if (lang === 'json' && EASYEDA_JSON_SIGNATURE.test(text.slice(0, 4000))) return { kind: 'easyeda' }
    const out =
      lang && hljs.getLanguage(lang) ? hljs.highlight(text, { language: lang }) : hljs.highlightAuto(text)
    return { kind: 'lines', lines: out.value.split('\n') }
  }
</script>

{#await load()}
  <Spinner />
{:then result}
  {#if result.kind === 'easyeda'}
    <Lazy load={() => import('./EasyEdaViewer.svelte')} props={{ path, source }} />
  {:else if result.kind === 'note'}
    {@render fallback(result.text)}
  {:else}
    <div class="repo-code hljs min-h-full text-[12.5px] leading-5">
      <table class="w-full border-collapse font-mono">
        <tbody>
          {#each result.lines as line, i (i)}
            <tr>
              <td class="w-px pr-3 pl-4 text-right align-top text-muted-foreground tabular-nums select-none">
                {i + 1}
              </td>
              <!-- eslint-disable-next-line svelte/no-at-html-tags -- highlight.js output escapes the source -->
              <td class="pr-4 align-top whitespace-pre">{@html line || '\n'}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
{:catch error}
  <p class="p-6 text-sm text-muted-foreground">Couldn’t load this file ({error.message}).</p>
{/await}
