import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count", "items", "empty"]

  connect() {
    this.observer = new MutationObserver(() => this.updateCount())
    this.observer.observe(this.itemsTarget, { childList: true })
    this.updateCount()
  }

  disconnect() {
    this.observer.disconnect()
  }

  updateCount() {
    const count = this.itemsTarget.children.length
    this.countTarget.textContent = count > 0 ? ` (${count})` : ""
    this.itemsTarget.hidden = count === 0
    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = count > 0
    }
  }
}
