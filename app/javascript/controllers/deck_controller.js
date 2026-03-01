import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["columns", "modal", "modalTitle", "form", "feedId", "nameInput", "sourceCheckbox", "autoIncludeCheckbox", "includeDmsCheckbox"]

  connect() {
    this.sortable = Sortable.create(this.columnsTarget, {
      animation: 150,
      delay: 100,
      delayOnTouchOnly: true,
      handle: ".feed-column-header",
      draggable: "[data-feed-id]",
      ghostClass: "opacity-30",
      onEnd: this.onReorder.bind(this)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async onReorder(event) {
    const feedId = event.item.dataset.feedId
    const newPosition = event.newIndex
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      await fetch(`/feeds/${feedId}/move`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ position: newPosition })
      })
    } catch {
      // Revert on failure by reloading
      window.location.reload()
    }
  }

  openAddModal() {
    this.modalTitleTarget.textContent = "Add Column"
    this.feedIdTarget.value = ""
    this.nameInputTarget.value = ""
    this.sourceCheckboxTargets.forEach(cb => cb.checked = false)
    this.autoIncludeCheckboxTargets.forEach(cb => cb.checked = false)
    this.includeDmsCheckboxTargets.forEach(cb => cb.checked = false)
    this.modalTarget.hidden = false
  }

  openEditModal(event) {
    const button = event.currentTarget
    const feedId = button.dataset.feedId
    const feedName = button.dataset.feedName
    const sourceIds = (button.dataset.feedSourceIds || "").split(",").filter(Boolean)
    const autoWorkspaceIds = (button.dataset.feedAutoIncludeWorkspaceIds || "").split(",").filter(Boolean)
    const includeDmsWorkspaceIds = (button.dataset.feedIncludeDmsWorkspaceIds || "").split(",").filter(Boolean)

    this.modalTitleTarget.textContent = "Edit Column"
    this.feedIdTarget.value = feedId
    this.nameInputTarget.value = feedName
    this.sourceCheckboxTargets.forEach(cb => {
      cb.checked = sourceIds.includes(cb.dataset.sourceId)
    })
    this.autoIncludeCheckboxTargets.forEach(cb => {
      cb.checked = autoWorkspaceIds.includes(cb.dataset.workspaceId)
    })
    this.includeDmsCheckboxTargets.forEach(cb => {
      cb.checked = includeDmsWorkspaceIds.includes(cb.dataset.workspaceId)
    })
    this.modalTarget.hidden = false
  }

  toggleWorkspace(event) {
    const workspaceId = event.currentTarget.dataset.workspaceId
    const checkboxes = this.sourceCheckboxTargets.filter(cb => cb.dataset.workspaceId === workspaceId)
    const allChecked = checkboxes.every(cb => cb.checked)
    checkboxes.forEach(cb => cb.checked = !allChecked)
    event.currentTarget.textContent = allChecked ? "Select All" : "Deselect All"
  }

  closeModal() {
    this.modalTarget.hidden = true
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  async submitForm(event) {
    event.preventDefault()
    const feedId = this.feedIdTarget.value
    const name = this.nameInputTarget.value
    const sourceIds = this.sourceCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const isEdit = feedId !== ""

    const url = isEdit ? `/feeds/${feedId}` : "/feeds"
    const method = isEdit ? "PATCH" : "POST"

    try {
      const response = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({
          name,
          source_ids: sourceIds,
          auto_include_workspace_ids: this.autoIncludeCheckboxTargets.filter(cb => cb.checked).map(cb => cb.value),
          include_dms_workspace_ids: this.includeDmsCheckboxTargets.filter(cb => cb.checked).map(cb => cb.value)
        })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        this.closeModal()
      }
    } catch {
      // ignore
    }
  }

  async removeColumn(event) {
    const feedId = event.currentTarget.dataset.feedId
    if (!confirm("Remove this column?")) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(`/feeds/${feedId}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch {
      // ignore
    }
  }
}
