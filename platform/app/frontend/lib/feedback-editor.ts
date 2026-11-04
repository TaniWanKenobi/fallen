import { Editor } from '@tiptap/core'
import { Placeholder } from '@tiptap/extensions'
import { Markdown } from '@tiptap/markdown'
import StarterKit from '@tiptap/starter-kit'

// The journal review feedback box: formats as it's typed (`**bold**`, `_italic_`, `- ` for a list) and stores
// Markdown. Only what Slack can show is on (SlackMessages.mrkdwn): no headings, quotes, code or underline.
export function createFeedbackEditor({
  element,
  markdown,
  placeholder,
  onChange,
  onRedraw,
  onLink,
}: {
  element: HTMLElement
  markdown: string
  placeholder: string
  onChange: (markdown: string) => void
  onRedraw: () => void
  onLink: () => void
}): Editor {
  return new Editor({
    element,
    extensions: [
      StarterKit.configure({
        heading: false,
        blockquote: false,
        code: false,
        codeBlock: false,
        horizontalRule: false,
        underline: false,
        link: { openOnClick: false, autolink: true, defaultProtocol: 'https' },
      }),
      Placeholder.configure({ placeholder }),
      Markdown.configure({ markedOptions: { gfm: true, breaks: true } }),
    ],
    content: markdown,
    contentType: 'markdown',
    editorProps: {
      attributes: { class: 'feedback-editor', 'aria-multiline': 'true', role: 'textbox' },
      // ⌘Enter sends the review (the page's shortcut), so it isn't a line break here; ⌘K adds a link.
      handleKeyDown: (_view, event) => {
        if (!(event.metaKey || event.ctrlKey) || event.altKey || event.shiftKey) return false
        if (event.key === 'Enter') return true
        if (event.key.toLowerCase() === 'k') {
          event.preventDefault()
          onLink()
          return true
        }
        return false
      },
    },
    onUpdate: ({ editor }) => onChange(editor.getMarkdown()),
    onTransaction: onRedraw,
  })
}
