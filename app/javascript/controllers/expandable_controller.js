import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "toggle"]

  connect() {
    if (this.contentTarget.scrollHeight <= this.contentTarget.clientHeight) {
      this.toggleTarget.hidden = true
    }
  }

  toggle() {
    const expanded = this.contentTarget.classList.toggle("max-h-none")
    this.contentTarget.classList.toggle("overflow-hidden", !expanded)
    this.toggleTarget.textContent = expanded ? "Show less" : "Show more"
  }
}
