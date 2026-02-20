import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { since: String, stoppedAt: String }
  static targets = ["display"]

  connect() {
    this.update()
    if (!this.hasStoppedAtValue || !this.stoppedAtValue) {
      this.interval = setInterval(() => this.update(), 1000)
    }
  }

  disconnect() {
    if (this.interval) clearInterval(this.interval)
  }

  update() {
    const end = this.hasStoppedAtValue && this.stoppedAtValue ? new Date(this.stoppedAtValue) : Date.now()
    const elapsed = Math.max(0, Math.floor((end - new Date(this.sinceValue)) / 1000))
    const hours = Math.floor(elapsed / 3600)
    const minutes = Math.floor((elapsed % 3600) / 60)
    const seconds = elapsed % 60

    let text
    if (hours > 0) {
      text = `${hours}h ${minutes}m`
    } else if (minutes > 0) {
      text = `${minutes}m ${seconds}s`
    } else {
      text = `${seconds}s`
    }

    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = text
    }
  }
}
