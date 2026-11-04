<script lang="ts">
  import Bold from '@lucide/svelte/icons/bold'
  import Italic from '@lucide/svelte/icons/italic'
  import Link from '@lucide/svelte/icons/link'
  import List from '@lucide/svelte/icons/list'
  import ListOrdered from '@lucide/svelte/icons/list-ordered'
  import Strikethrough from '@lucide/svelte/icons/strikethrough'
  import type { Editor } from '@tiptap/core'
  import { onMount, type Component } from 'svelte'
  import { chunk } from '@/lib/chunks'

  // The journal review feedback, written like Obsidian: Markdown formats as it's typed and is what's stored.
  let {
    labelledby,
    value = $bindable(''),
    placeholder = '',
    onSubmit,
  }: { labelledby?: string; value: string; placeholder?: string; onSubmit?: () => void } = $props()

  let mount: HTMLDivElement | undefined = $state()
  let editor: Editor | undefined = $state.raw()
  // Tiptap's editor isn't reactive; this ticks on every transaction so the toolbar re-reads it.
  let redraws = $state(0)
  let linking = $state(false)
  let linkUrl = $state('')
  // What the editor last wrote, so a change from outside (a restored draft) is told apart.
  let written = value

  onMount(() => {
    let destroyed = false
    chunk(import('@/lib/feedback-editor')).then(({ createFeedbackEditor }) => {
      if (destroyed || !mount) return
      editor = createFeedbackEditor({
        element: mount,
        markdown: value,
        placeholder,
        onChange: (markdown) => (value = written = markdown.trimEnd()),
        onRedraw: () => queueMicrotask(() => redraws++),
        onLink: openLink,
        onSubmit: onSubmit && (() => onSubmit()),
      })
      if (labelledby) editor.view.dom.setAttribute('aria-labelledby', labelledby)
    })
    return () => {
      destroyed = true
      editor?.destroy()
    }
  })

  $effect(() => {
    if (!editor || value === written) return
    written = value
    editor.commands.setContent(value, { contentType: 'markdown', emitUpdate: false })
  })

  type Tool = { label: string; keys: string; icon: Component; active: string; run: (e: Editor) => void }

  const tools: Tool[] = [
    {
      label: 'Bold',
      keys: 'B',
      icon: Bold,
      active: 'bold',
      run: (e) => e.chain().focus().toggleBold().run(),
    },
    {
      label: 'Italic',
      keys: 'I',
      icon: Italic,
      active: 'italic',
      run: (e) => e.chain().focus().toggleItalic().run(),
    },
    {
      label: 'Strikethrough',
      keys: 'Shift S',
      icon: Strikethrough,
      active: 'strike',
      run: (e) => e.chain().focus().toggleStrike().run(),
    },
    { label: 'Link', keys: 'K', icon: Link, active: 'link', run: () => openLink() },
    {
      label: 'Bulleted list',
      keys: 'Shift 8',
      icon: List,
      active: 'bulletList',
      run: (e) => e.chain().focus().toggleBulletList().run(),
    },
    {
      label: 'Numbered list',
      keys: 'Shift 7',
      icon: ListOrdered,
      active: 'orderedList',
      run: (e) => e.chain().focus().toggleOrderedList().run(),
    },
  ]

  const mod = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl+'

  function isActive(name: string) {
    void redraws
    return editor?.isActive(name) ?? false
  }

  function openLink() {
    if (!editor) return
    linkUrl = editor.getAttributes('link').href ?? ''
    linking = true
  }

  function closeLink() {
    linking = false
    editor?.view.focus()
  }

  function applyLink() {
    if (!editor) return
    const typed = linkUrl.trim()
    const href = typed && !/^[a-z][a-z\d+.-]*:/i.test(typed) ? `https://${typed}` : typed
    const chain = editor.chain().focus().extendMarkRange('link')
    if (!href) chain.unsetLink().run()
    else if (editor.state.selection.empty && !editor.isActive('link'))
      chain.insertContent({ type: 'text', text: typed, marks: [{ type: 'link', attrs: { href } }] }).run()
    else chain.setLink({ href }).run()
    closeLink()
  }

  export function focus() {
    editor?.commands.focus('end')
  }
</script>

<div
  class="rounded-md border border-input bg-transparent shadow-xs transition-[color,box-shadow] focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/50 dark:bg-input/30"
>
  <div class="flex h-8 items-center gap-0.5 border-b border-input px-1">
    {#if linking}
      <Link class="ml-1 size-3.5 shrink-0 text-muted-foreground" />
      <input
        {@attach (input) => input.select()}
        bind:value={linkUrl}
        type="text"
        inputmode="url"
        placeholder="Paste a link"
        aria-label="Link address"
        onkeydown={(e) => {
          if (e.key === 'Enter') {
            e.preventDefault()
            applyLink()
          } else if (e.key === 'Escape') {
            e.stopPropagation()
            closeLink()
          }
        }}
        class="min-w-0 flex-1 border-0 bg-transparent px-1 py-0 text-xs focus:ring-0 focus:outline-none"
      />
      <button type="button" class="tool-text" onclick={applyLink}
        >{linkUrl.trim() ? 'Apply' : 'Remove'}</button
      >
      <button type="button" class="tool-text" onclick={closeLink}>Cancel</button>
    {:else}
      {#each tools as tool (tool.label)}
        <button
          type="button"
          class="tool"
          aria-label={tool.label}
          aria-pressed={isActive(tool.active)}
          title="{tool.label} ({mod}{tool.keys})"
          disabled={!editor}
          onclick={() => editor && tool.run(editor)}
        >
          <tool.icon class="size-3.5" strokeWidth={2.4} />
        </button>
      {/each}
    {/if}
  </div>
  <div bind:this={mount} class="max-h-96 min-h-32 resize-y overflow-y-auto"></div>
</div>

<style>
  .tool {
    display: flex;
    width: 1.75rem;
    height: 1.75rem;
    align-items: center;
    justify-content: center;
    border-radius: 0.375rem;
    color: var(--color-muted-foreground);
    cursor: pointer;
    transition:
      background-color 120ms,
      color 120ms;
  }
  .tool:hover:not(:disabled) {
    background: color-mix(in srgb, var(--color-blue-500) 15%, transparent);
    color: var(--color-blue-600);
  }
  .tool:active:not(:disabled) {
    background: color-mix(in srgb, var(--color-blue-500) 28%, transparent);
  }
  /* The format under the cursor is on: solid, so it reads apart from a hover. */
  .tool[aria-pressed='true'],
  .tool[aria-pressed='true']:hover:not(:disabled) {
    background: var(--color-blue-600);
    color: white;
  }
  :global(.admin.dark) .tool:hover:not(:disabled) {
    color: var(--color-blue-300);
  }
  :global(.admin.dark) .tool[aria-pressed='true'],
  :global(.admin.dark) .tool[aria-pressed='true']:hover:not(:disabled) {
    background: var(--color-blue-500);
    color: white;
  }
  .tool:disabled {
    cursor: default;
    opacity: 0.5;
  }
  .tool-text {
    border-radius: 0.375rem;
    padding: 0.125rem 0.375rem;
    font-size: 0.75rem;
    font-weight: 500;
    color: var(--color-muted-foreground);
    cursor: pointer;
  }
  .tool-text:hover {
    background: var(--color-muted);
    color: var(--color-foreground);
  }
  div :global(.feedback-editor) {
    min-height: 8rem;
    padding: 0.5rem 0.75rem;
    font-size: 0.875rem;
    line-height: 1.5;
    outline: none;
    overflow-wrap: anywhere;
  }
  div :global(.feedback-editor > * + *) {
    margin-top: 0.5rem;
  }
  div :global(.feedback-editor strong) {
    font-weight: 600;
  }
  div :global(.feedback-editor a) {
    color: var(--color-blue-600);
    text-decoration: underline;
    text-underline-offset: 2px;
  }
  div :global(.feedback-editor ul) {
    list-style: disc;
    padding-left: 1.25rem;
  }
  div :global(.feedback-editor ol) {
    list-style: decimal;
    padding-left: 1.25rem;
  }
  div :global(.feedback-editor p.is-editor-empty:first-child::before) {
    content: attr(data-placeholder);
    float: left;
    height: 0;
    pointer-events: none;
    color: var(--color-muted-foreground);
    opacity: 0.5;
  }
</style>
