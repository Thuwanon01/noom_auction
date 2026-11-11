import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Uploads each chosen file in its own request so one failure never loses the others.
// Each file gets a progress bar; a failed file shows its error and a Retry button.
export default class extends Controller {
  static targets = ["input", "list"]
  static values = { max: Number, existing: Number }

  pick(event) {
    const input = event.target
    const files = Array.from(input.files)
    input.value = ""
    const room = input.dataset.single ? Infinity : this.maxValue - this.existingValue
    files.forEach((file, i) => {
      const row = this.addRow(file)
      const error = this.check(file, input) || (i >= room ? `เกินจำนวนสูงสุด ${this.maxValue} รูป` : null)
      error ? this.fail(row, file, input, error, false) : this.send(row, file, input)
    })
  }

  check(file, input) {
    const types = input.dataset.types.split(",")
    if (!types.includes(file.type)) return "ชนิดไฟล์ไม่รองรับ"
    if (file.size > Number(input.dataset.maxBytes)) return "ไฟล์ใหญ่เกินกำหนด"
    return null
  }

  addRow(file) {
    const li = document.createElement("li")
    li.className = "uploads__row"
    li.innerHTML = `<span class="uploads__name"></span><progress max="100" value="0"></progress><span class="uploads__msg"></span>`
    li.querySelector(".uploads__name").textContent = file.name
    this.listTarget.appendChild(li)
    return li
  }

  send(row, file, input) {
    const bar = row.querySelector("progress")
    row.querySelector(".uploads__msg").textContent = ""
    row.querySelector("button")?.remove()
    const xhr = new XMLHttpRequest()
    xhr.open("POST", input.dataset.url)
    xhr.setRequestHeader("Accept", "application/json")
    xhr.setRequestHeader("X-CSRF-Token", document.querySelector("meta[name=csrf-token]")?.content || "")
    xhr.upload.onprogress = (e) => { if (e.lengthComputable) bar.value = (e.loaded / e.total) * 100 }
    xhr.onload = () => {
      if (xhr.status === 201) { bar.value = 100; row.dataset.done = "1"; this.finishIfAllDone() }
      else {
        let msg = "อัปโหลดไม่สำเร็จ"
        try { msg = JSON.parse(xhr.responseText).errors.join(", ") } catch (_) {}
        this.fail(row, file, input, msg, xhr.status >= 500)
      }
    }
    xhr.onerror = () => this.fail(row, file, input, "การเชื่อมต่อขัดข้อง", true)
    const form = new FormData()
    form.append("file", file)
    xhr.send(form)
  }

  fail(row, file, input, message, retryable) {
    row.dataset.failed = "1"
    queueMicrotask(() => this.finishIfAllDone())
    row.querySelector(".uploads__msg").textContent = message
    if (!retryable) return
    const button = document.createElement("button")
    button.type = "button"
    button.className = "btn btn--ghost"
    button.textContent = "ลองอีกครั้ง"
    button.addEventListener("click", () => { delete row.dataset.failed; this.send(row, file, input) })
    row.appendChild(button)
  }

  // When every file has settled: reload to show the new photos, unless some failed. Then keep the failed rows
  // (and their messages / Retry buttons) on screen and offer a manual reload instead.
  finishIfAllDone() {
    const rows = Array.from(this.listTarget.children)
    const pending = rows.some((r) => !r.dataset.done && !r.dataset.failed)
    if (pending || !rows.some((r) => r.dataset.done)) return
    if (rows.every((r) => r.dataset.done)) return Turbo.visit(window.location.href, { action: "replace" })
    if (this.element.querySelector(".uploads__reload")) return
    const button = document.createElement("button")
    button.type = "button"
    button.className = "btn btn--ghost uploads__reload"
    button.textContent = "อัปโหลดสำเร็จบางไฟล์ รีเฟรชเพื่อดูรูป"
    button.addEventListener("click", () => Turbo.visit(window.location.href, { action: "replace" }))
    this.listTarget.after(button)
  }
}
