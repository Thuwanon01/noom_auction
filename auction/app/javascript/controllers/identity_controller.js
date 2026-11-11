import { Controller } from "@hotwired/stimulus"

// Step 1 of onboarding. Enables "Next" only when the national ID passes the
// checksum, the phone matches the one verified by OTP, and PDPA is ticked.
// The server checks all of this again; this is only for quicker feedback.
export default class extends Controller {
  static targets = ["nationalId", "idHint", "phone", "consent", "next", "verifiedBadge"]
  static values = { verifiedPhone: String }

  connect() {
    this.check()
  }

  check() {
    const id = this.digits(this.nationalIdTarget.value)
    const idValid = this.validId(id)
    this.idHintTarget.hidden = id.length < 13 || idValid

    const phoneVerified = this.verifiedPhoneValue !== "" &&
      this.digits(this.phoneTarget.value) === this.verifiedPhoneValue
    if (this.hasVerifiedBadgeTarget) this.verifiedBadgeTarget.hidden = !phoneVerified

    this.nextTarget.disabled = !(idValid && phoneVerified && this.consentTarget.checked)
  }

  digits(value) {
    return value.replace(/[\s-]/g, "")
  }

  validId(id) {
    if (!/^\d{13}$/.test(id)) return false
    let sum = 0
    for (let i = 0; i < 12; i++) sum += Number(id[i]) * (13 - i)
    return (11 - (sum % 11)) % 10 === Number(id[12])
  }
}
