import { Controller } from "@hotwired/stimulus"

// Adds a thousands separator while typing: 1250000 -> 1,250,000.
// The server strips the commas again (User#annual_income=).
export default class extends Controller {
  connect() {
    this.format()
  }

  format() {
    const input = this.element
    const raw = input.value.replace(/[^\d.]/g, "")
    const [whole, ...rest] = raw.split(".")
    const decimals = rest.length ? "." + rest.join("").slice(0, 2) : ""
    const formatted = (whole ? Number(whole).toLocaleString("en-US") : "") + decimals
    if (formatted === input.value) return

    const fromEnd = input.value.length - (input.selectionStart ?? input.value.length)
    input.value = formatted
    const pos = Math.max(formatted.length - fromEnd, 0)
    input.setSelectionRange?.(pos, pos)
  }
}
