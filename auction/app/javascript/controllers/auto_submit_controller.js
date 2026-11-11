import { Controller } from "@hotwired/stimulus"

// Submits its form shortly after it appears, so the "Calculating…" state is
// visible for a moment. The button stays as a fallback without JavaScript.
export default class extends Controller {
  static targets = ["button"]
  static values = { delay: { type: Number, default: 700 } }

  connect() {
    if (this.hasButtonTarget) this.buttonTarget.hidden = true
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
