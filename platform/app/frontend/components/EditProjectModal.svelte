<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import HoldButton from '@/components/HoldButton.svelte'
  import ModalButton from '@/components/ModalButton.svelte'
  import Modal from '@/components/Modal.svelte'
  import ProjectFields from '@/components/ProjectFields.svelte'
  import { projectForm, saveProject } from '@/lib/projectForm'
  import { projects } from '@/routes'
  import type { Project } from '@/types'

  // Editing in place on the project page. Projects/Form.svelte still serves a direct visit to /projects/:id/edit.
  // Deleting lives here, behind its own step: people deleted projects by accident when it sat next to Edit.
  let {
    project,
    directUploadUrl,
    canDelete = false,
    onClose,
  }: {
    project: Project
    directUploadUrl: string | undefined
    canDelete?: boolean
    onClose: () => void
  } = $props()

  // svelte-ignore state_referenced_locally
  const form = projectForm(project)
  let root: HTMLFormElement = $state()!
  let deleting = $state(false)
  let typed = $state('')
  const named = $derived(typed.trim().toLowerCase() === project.title.trim().toLowerCase())

  function submit(event: SubmitEvent) {
    event.preventDefault()
    saveProject(form, project, root, onClose, { preserveScroll: true })
  }

  function back() {
    deleting = false
    typed = ''
  }
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && (deleting ? back() : onClose())} />

<Modal titleId="edit-project-title" title={deleting ? 'Delete Project' : 'Edit Project'} {onClose}>
  {#if deleting}
    <div class="px-5 pt-2 pb-6 md:px-9 md:pb-8">
      <p class="text-center font-outfit text-sm text-ink md:text-base">
        This deletes <strong>{project.title}</strong> and its {project.journal_count}
        {project.journal_count === 1 ? 'journal' : 'journals'} ({project.journal_count === 0
          ? 'nothing logged'
          : 'all the time logged on them'}). You can't undo it yourself. The Slack thread stays.
      </p>

      <label for="delete-project-name" class="mt-5 block font-outfit text-sm text-ink">
        Type the project's name to confirm
      </label>
      <!-- svelte-ignore a11y_autofocus -->
      <input
        id="delete-project-name"
        bind:value={typed}
        autocomplete="off"
        autofocus
        placeholder={project.title}
        class="paper-input mt-1"
      />

      <div class="mt-6 flex flex-col-reverse items-center justify-center gap-3 sm:flex-row md:mt-8">
        <ModalButton kind="cancel" onclick={back}>Keep it</ModalButton>
        {#if named}
          <HoldButton
            label="Hold to delete"
            done="Deleting"
            seconds={1.5}
            onconfirm={() => router.delete(projects.destroy(project.id).url)}
            game
          />
        {:else}
          <ModalButton kind="confirm" disabled>Hold to delete</ModalButton>
        {/if}
      </div>
    </div>
  {:else}
    <form
      bind:this={root}
      onsubmit={submit}
      novalidate
      class="max-h-[calc(90vh-130px)] overflow-x-hidden overflow-y-auto px-5 pt-2 pb-6 md:px-9 md:pb-8"
    >
      <ProjectFields {form} {directUploadUrl} banner={false} />

      <div class="mt-6 flex flex-col-reverse justify-center gap-3 sm:flex-row md:mt-8">
        <ModalButton kind="cancel" onclick={onClose}>Cancel</ModalButton>
        <ModalButton kind="confirm" type="submit" disabled={form.processing || form.title.trim() === ''}>
          {form.processing ? 'Saving...' : 'Save'}
        </ModalButton>
      </div>

      {#if canDelete}
        <p class="mt-6 text-center">
          <button
            type="button"
            class="cursor-pointer font-outfit text-xs text-ink-soft underline underline-offset-2 hover:text-hc-red"
            onclick={() => (deleting = true)}>Delete this project</button
          >
        </p>
      {/if}
    </form>
  {/if}
</Modal>
