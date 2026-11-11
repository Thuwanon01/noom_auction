import { Controller } from "@hotwired/stimulus"

// Swap the cover image when a thumbnail is clicked (M3.7).
export default class extends Controller {
  static targets = ["cover"]

  show({ params: { url }, currentTarget }) {
    if (!this.hasCoverTarget) return
    this.coverTarget.src = url
    this.element.querySelectorAll(".gallery__thumb").forEach((el) => el.classList.toggle("is-on", el === currentTarget))
  }
}
