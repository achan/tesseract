import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon", "label"]

  toggle() {
    const hidden = this.contentTarget.hidden
    this.contentTarget.hidden = !hidden
    this.iconTarget.classList.toggle("rotate-90", hidden)
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = hidden ? "Hide details" : "Show details"
    }
  }
}
