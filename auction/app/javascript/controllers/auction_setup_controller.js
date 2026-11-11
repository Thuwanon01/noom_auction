import { Controller } from "@hotwired/stimulus"

// Shows only the fields of the chosen auction type (hidden groups are disabled so they are not submitted;
// the server also ignores them) and keeps the preview card in sync.
export default class extends Controller {
  static targets = ["type", "group", "price", "previewType", "previewPrice"]
  static values = { name: String }

  connect() { this.refresh() }

  refresh() {
    const chosen = this.typeTargets.find((r) => r.checked)
    const type = chosen?.value
    this.groupTargets.forEach((g) => {
      const on = g.dataset.type === type
      g.hidden = !on
      g.querySelectorAll("input").forEach((i) => (i.disabled = !on))
    })
    if (chosen) this.previewTypeTarget.textContent = chosen.closest("label").querySelector("strong").textContent
    const price = parseInt(this.priceTarget.value, 10)
    this.previewPriceTarget.textContent = Number.isFinite(price) ? price.toLocaleString("th-TH") : "0"
  }
}
