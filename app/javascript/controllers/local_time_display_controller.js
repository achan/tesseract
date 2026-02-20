import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const iso = this.element.getAttribute("datetime")
    if (!iso) return

    const date = new Date(iso)
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    const month = months[date.getMonth()]
    const dateNum = date.getDate()

    let hours = date.getHours()
    const minutes = date.getMinutes().toString().padStart(2, "0")
    const ampm = hours >= 12 ? "PM" : "AM"
    hours = hours % 12 || 12

    this.element.textContent = `${month} ${dateNum}, ${hours}:${minutes} ${ampm}`
  }
}
