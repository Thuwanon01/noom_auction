import { Controller } from "@hotwired/stimulus"

// Catalog filters (M3.4): debounced search and auto-submit for filter controls.
// The form targets the "catalog" Turbo Frame with turbo-action "advance",
// so the list updates in place and the URL keeps the full filter state.
export default class extends Controller {
  static targets = ["form", "query"]
  static values = { delay: { type: Number, default: 300 } }

  disconnect() {
    clearTimeout(this.timer)
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.submit(), this.delayValue)
  }

  submit() {
    clearTimeout(this.timer)
    this.formTarget.requestSubmit()
  }

  // Keep URLs short: drop empty fields (blank search, "ทุกราคา") before submit.
  compact(event) {
    for (const [key, value] of [...event.formData.entries()]) {
      if (value === "") event.formData.delete(key)
    }
  }

  // After a link inside the frame (chip, clear all, tab) loads, keep the
  // search box in step with the new URL unless the user is typing in it.
  sync(event) {
    if (document.activeElement === this.queryTarget) return
    const src = event.target.getAttribute("src")
    if (!src) return
    this.queryTarget.value = new URL(src, window.location.href).searchParams.get("q") || ""
  }
}
