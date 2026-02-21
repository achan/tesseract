import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "content"]

  openNew(event) {
    event.preventDefault()
    event.stopPropagation()

    const status = event.currentTarget.dataset.status || "untriaged"
    this.fetchAndShow(`/action_items/new?status=${status}`)
  }

  openEdit(event) {
    event.preventDefault()
    event.stopPropagation()

    const url = event.currentTarget.dataset.editUrl
    if (!url) return

    this.fetchAndShow(url)
  }

  async fetchAndShow(url) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(url, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": token
      }
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
      this.show()
    }
  }

  show() {
    this.overlayTarget.hidden = false
    document.body.style.overflow = "hidden"
  }

  close() {
    this.overlayTarget.hidden = true
    document.body.style.overflow = ""
    this.contentTarget.innerHTML = ""
  }

  closeOnKey(event) {
    if (event.key === "Escape" && !this.overlayTarget.hidden) {
      this.close()
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
