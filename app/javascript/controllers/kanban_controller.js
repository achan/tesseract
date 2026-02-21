import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["column"]

  connect() {
    this.sortables = this.columnTargets.map((column) => {
      return Sortable.create(column, {
        group: "kanban",
        animation: 150,
        delay: 100,
        delayOnTouchOnly: true,
        draggable: "[data-id]",
        ghostClass: "opacity-30",
        onEnd: this.onEnd.bind(this)
      })
    })
  }

  async onEnd(event) {
    const itemEl = event.item
    const id = itemEl.dataset.id
    const newStatus = event.to.dataset.status

    if (itemEl.dataset.status === newStatus && event.oldIndex === event.newIndex) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const response = await fetch(`/action_items/${id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ action_item: { status: newStatus } })
      })

      if (response.ok) {
        itemEl.dataset.status = newStatus
      } else {
        event.from.insertBefore(itemEl, event.from.children[event.oldIndex] || null)
      }
    } catch {
      event.from.insertBefore(itemEl, event.from.children[event.oldIndex] || null)
    }
  }

  disconnect() {
    this.sortables?.forEach((s) => s.destroy())
  }
}
