import { Controller } from "@hotwired/stimulus"

// Live countdown to a moment (M3.7). Shared with the M4 Dutch price countdown.
//   <span data-controller="countdown" data-countdown-to-value="2026-11-11T14:00:00Z">5 ชม.</span>
// Mirrors AuctionsHelper#thai_duration. When it reaches zero it shows the
// done text and dispatches "countdown:done" so a page can refresh.
export default class extends Controller {
  static values = { to: String, done: { type: String, default: "ปิดแล้ว" }, interval: { type: Number, default: 1000 } }

  connect() {
    this.deadline = Date.parse(this.toValue)
    if (Number.isNaN(this.deadline)) return
    this.tick()
    this.timer = setInterval(() => this.tick(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const seconds = (this.deadline - Date.now()) / 1000
    if (seconds <= 0) {
      clearInterval(this.timer)
      this.element.textContent = this.doneValue
      this.dispatch("done")
      return
    }
    this.element.textContent = this.constructor.format(seconds)
  }

  static format(seconds) {
    const minutes = Math.ceil(seconds / 60)
    if (minutes < 60) return `${Math.max(minutes, 1)} นาที`
    if (minutes < 24 * 60) return `${Math.ceil(minutes / 60)} ชม.`
    return `${Math.ceil(minutes / (24 * 60))} วัน`
  }
}
