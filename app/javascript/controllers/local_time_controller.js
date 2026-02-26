import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const iso = this.element.getAttribute("datetime")
    if (!iso) return

    const date = new Date(iso)
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    const day = days[date.getDay()]
    const month = months[date.getMonth()]
    const dateNum = date.getDate()
    const year = date.getFullYear()

    let hours = date.getHours()
    const minutes = date.getMinutes().toString().padStart(2, "0")
    const ampm = hours >= 12 ? "p" : "a"
    const ampmFull = hours >= 12 ? "pm" : "am"
    hours = hours % 12 || 12

    this.element.textContent = `${hours}:${minutes}${ampm}`
    this.element.title = `${day}, ${month} ${dateNum} ${year} ${hours}:${minutes}${ampmFull}`
  }
}
