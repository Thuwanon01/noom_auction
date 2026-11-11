import { Controller } from "@hotwired/stimulus"

// Re-fetches the current page, e.g. when a Dutch price drop countdown ends.
//   data-controller="countdown reload" data-action="countdown:done->reload#now"
export default class extends Controller {
  now() {
    window.Turbo.visit(window.location.href, { action: "replace" })
  }
}
