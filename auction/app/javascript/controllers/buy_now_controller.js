import { Controller } from "@hotwired/stimulus"

// Dutch "Buy now" (M4.7): confirm the price at that moment. After a
// "Price changed" response the page re-renders with the new price and
// reconfirm=true, so the dialog opens again straight away.
export default class extends Controller {
  static targets = ["dialog", "message", "error"]
  static values = { price: Number, reconfirm: Boolean }

  connect() {
    this.keepWhileBusy = (event) => {
      if (event.target === this.element && this.busy) event.preventDefault()
    }
    document.addEventListener("turbo:before-morph-element", this.keepWhileBusy)
    if (this.reconfirmValue) this.open(`The price is now ${this.baht(this.priceValue)}. Buy now?`)
  }

  disconnect() {
    document.removeEventListener("turbo:before-morph-element", this.keepWhileBusy)
  }

  // Do not morph the form away while the confirm dialog is open (M4.9).
  get busy() {
    return this.dialogTarget.open
  }

  confirm(event) {
    if (this.confirmed) { this.confirmed = false; return }
    event.preventDefault()
    this.open(`Buy now at ${this.baht(this.priceValue)}?`)
  }

  open(text) {
    this.messageTarget.textContent = text
    this.dialogTarget.showModal()
  }

  accept() {
    this.dialogTarget.close()
    this.confirmed = true
    this.element.requestSubmit()
  }

  cancel() {
    this.dialogTarget.close()
  }

  networkError() {
    this.errorTarget.textContent = "Could not place your bid. Please try again"
    this.errorTarget.hidden = false
  }

  submitEnd(event) {
    if (!event.detail.success && !event.detail.fetchResponse) this.networkError()
  }

  baht(n) {
    return `฿${n.toLocaleString("en-US")}`
  }
}
