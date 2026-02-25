import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.observer = new MutationObserver(() => this.sort())
    this.observer.observe(this.element, { childList: true, attributes: true, attributeFilter: ["data-sort-key"] })
  }

  disconnect() {
    this.observer.disconnect()
  }

  sort() {
    const children = Array.from(this.element.children)
    const sorted = children.slice().sort((a, b) => {
      const keyA = a.dataset.sortKey || ""
      const keyB = b.dataset.sortKey || ""
      return keyA.localeCompare(keyB, undefined, { numeric: true })
    })

    let needsReorder = false
    for (let i = 0; i < children.length; i++) {
      if (children[i] !== sorted[i]) {
        needsReorder = true
        break
      }
    }

    if (needsReorder) {
      this.observer.disconnect()
      sorted.forEach(child => this.element.appendChild(child))
      this.observer.observe(this.element, { childList: true, attributes: true, attributeFilter: ["data-sort-key"] })
    }
  }
}
