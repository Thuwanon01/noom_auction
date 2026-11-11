import { Controller } from "@hotwired/stimulus"

// Drag a photo to a new position; the new order is saved immediately. The first photo is the cover.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.element.addEventListener("dragstart", (e) => { this.dragged = e.target.closest("li"); this.dragged?.classList.add("is-dragging") })
    this.element.addEventListener("dragover", (e) => {
      e.preventDefault()
      const over = e.target.closest("li")
      if (!this.dragged || !over || over === this.dragged) return
      const after = e.clientX > over.getBoundingClientRect().left + over.offsetWidth / 2
      over.parentNode.insertBefore(this.dragged, after ? over.nextSibling : over)
    })
    this.element.addEventListener("dragend", () => { this.dragged?.classList.remove("is-dragging"); this.save() })
  }

  async save() {
    const ids = Array.from(this.element.querySelectorAll("li[data-id]")).map((li) => li.dataset.id)
    const body = new URLSearchParams(); ids.forEach((id) => body.append("ids[]", id))
    const res = await fetch(this.urlValue, {
      method: "PATCH", body,
      headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || "" }
    })
    if (res.ok) window.location.reload() // refresh so the cover badge moves to the new first photo
  }
}
