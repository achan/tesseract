import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.handleClick = this.handleClick.bind(this)
    this.element.addEventListener("click", this.handleClick)

    this.element.querySelectorAll("img.event-image").forEach((img) => {
      img.addEventListener("error", () => this.handleImageError(img))
    })
  }

  disconnect() {
    this.element.removeEventListener("click", this.handleClick)
  }

  handleImageError(img) {
    const permalink = img.dataset.permalink
    const link = img.closest("a.event-image-link")
    const wrapper = link || img

    const placeholder = document.createElement("a")
    placeholder.href = permalink || "#"
    if (permalink) {
      placeholder.target = "_blank"
      placeholder.rel = "noopener"
    }
    placeholder.className = "flex items-center gap-2 px-3 py-2 rounded-md bg-secondary text-sm text-muted hover:text-foreground"
    placeholder.innerHTML = `<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>${img.alt || "Image"}`

    wrapper.replaceWith(placeholder)
  }

  handleClick(event) {
    const img = event.target.closest("img.event-image")
    if (!img) return

    event.preventDefault()
    this.open(img)
  }

  open(img) {
    const overlay = this.overlayTarget
    const display = overlay.querySelector("img")
    display.src = img.src
    display.alt = img.alt
    overlay.hidden = false
    document.body.style.overflow = "hidden"
  }

  close() {
    this.overlayTarget.hidden = true
    document.body.style.overflow = ""
  }

  closeOnKey(event) {
    if (event.key === "Escape") this.close()
  }
}
