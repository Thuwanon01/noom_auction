import { Controller } from "@hotwired/stimulus"

// Bid form (M4.4): quick buttons, client-side checks and a confirm dialog.
// The server re-checks everything; this only saves a round trip.
export default class extends Controller {
  static targets = ["amount", "dialog", "message", "error"]
  static values = { title: String, min: Number, limit: Number }

  fill({ params: { amount } }) {
    this.amountTarget.value = amount
    this.hideError()
  }

  confirm(event) {
    if (this.confirmed) { this.confirmed = false; return }
    event.preventDefault()

    const raw = this.amountTarget.value.trim()
    const amount = Number(raw)
    if (!/^\d+$/.test(raw) || amount <= 0) return this.showError("Enter a valid amount")
    if (amount < this.minValue) return this.showError(`The minimum bid is ${this.baht(this.minValue)}`)
    if (this.hasLimitValue && this.limitValue > 0 && amount > this.limitValue) {
      return this.showError(`Over your bid limit. Your limit is ${this.baht(this.limitValue)}`)
    }

    this.hideError()
    this.messageTarget.textContent = `Bid ${this.baht(amount)} on ${this.titleValue}? A bid cannot be withdrawn.`
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

  // A request that never got a response: do not assume the bid was placed.
  networkError() {
    this.showError("Could not place your bid. Please try again")
  }

  submitEnd(event) {
    if (!event.detail.success && !event.detail.fetchResponse) this.networkError()
  }

  showError(text) {
    this.errorTarget.textContent = text
    this.errorTarget.hidden = false
  }

  hideError() {
    this.errorTarget.hidden = true
  }

  baht(n) {
    return `฿${n.toLocaleString("en-US")}`
  }
}
