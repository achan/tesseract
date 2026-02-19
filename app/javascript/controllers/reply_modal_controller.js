import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "authorName", "preview", "eventId", "textarea", "content", "error"]

  open(event) {
    const button = event.currentTarget
    this.authorNameTarget.textContent = button.dataset.authorName
    this.previewTarget.textContent = button.dataset.messagePreview
    this.eventIdTarget.value = button.dataset.eventId
    this.overlayTarget.hidden = false
    document.body.style.overflow = "hidden"
    this.textareaTarget.focus()
  }

  close() {
    this.overlayTarget.hidden = true
    document.body.style.overflow = ""
    this.textareaTarget.value = ""
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ""
    }
  }

  closeOnKey(event) {
    if (event.key === "Escape") this.close()
  }

  handleKeydown(event) {
    if (event.key !== "Enter") return

    event.preventDefault()

    if (event.metaKey) {
      const textarea = this.textareaTarget
      const { selectionStart, selectionEnd } = textarea
      textarea.value = textarea.value.slice(0, selectionStart) + "\n" + textarea.value.slice(selectionEnd)
      textarea.selectionStart = textarea.selectionEnd = selectionStart + 1
    } else {
      this.textareaTarget.form.requestSubmit()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  submitEnd(event) {
    if (event.detail.success) {
      this.close()
    }
  }
}
