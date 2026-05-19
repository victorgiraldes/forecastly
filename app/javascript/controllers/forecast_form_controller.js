import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  submit(event) {
    event.preventDefault()

    const zipCode = this.inputTarget.value.trim()
    if (zipCode) {
      window.location.href = `/forecasts/${encodeURIComponent(zipCode)}`
    }
  }
}
