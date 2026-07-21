import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue).then(() => {
      const el = this.element
      const original = el.innerHTML
      el.innerHTML = "Copied!"
      setTimeout(() => { el.innerHTML = original }, 1500)
    })
  }
}
