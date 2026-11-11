import { Controller } from "@hotwired/stimulus"

// Polling fallback for live updates (M4.9). While the Turbo Streams cable
// is connected the server pushes refreshes; if it is not, re-fetch the
// page every interval so price and history still move.
export default class extends Controller {
  static values = { interval: { type: Number, default: 15000 } }

  connect() {
    this.timer = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  poll() {
    if (document.hidden || this.cableConnected) return
    window.Turbo.session.refresh(window.location.href)
  }

  get cableConnected() {
    return document.querySelector("turbo-cable-stream-source[connected]") !== null
  }
}
