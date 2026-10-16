// The website's entry point: the menu, the quote form's show-and-hide, the
// cookie banner, then the theme's other scripts. A script of the theme's is
// a file in app/javascript/mulebox, imported here as "mulebox/<name>".
import "mulebox/forms"

// The small-screen menu (Navbar.astro's toggle).
const toggle = document.querySelector(".navbar__toggle")
toggle?.addEventListener("click", () => {
  const open = document.body.classList.toggle("menu-open")
  toggle.setAttribute("aria-expanded", open)
})

// An item with links under it opens them in place; one at a time, and a
// click anywhere else closes it.
const parents = [...document.querySelectorAll(".navbar__parent")]
const close = (except) => parents.forEach((button) => {
  if (button === except) return
  button.setAttribute("aria-expanded", "false")
  document.getElementById(button.getAttribute("aria-controls")).hidden = true
})
parents.forEach((button) => button.addEventListener("click", (event) => {
  event.stopPropagation()
  const menu = document.getElementById(button.getAttribute("aria-controls"))
  close(button)
  menu.hidden = !menu.hidden
  button.setAttribute("aria-expanded", String(!menu.hidden))
}))
document.addEventListener("click", (event) => { if (!event.target.closest(".navbar__menu")) close() })
document.addEventListener("keydown", (event) => { if (event.key === "Escape") close() })

// The quote form: the SMS consent's "View more", and the fields one service
// asks for (Move It's relocation ZIP, Store It's indoor or outdoor) shown
// only for it.
document.querySelectorAll("[data-consent-toggle]").forEach((button) => button.addEventListener("click", () => {
  const open = button.closest(".quote-form__consent").classList.toggle("is-open")
  button.setAttribute("aria-expanded", String(open))
  button.textContent = open ? "Show less" : "View more"
}))
document.querySelectorAll(".quote-form").forEach((form) => {
  const sync = () => {
    const service = form.querySelector("[name=service_type]:checked")?.value
    form.querySelectorAll("[data-service]").forEach((field) => {
      const shown = field.dataset.service === service
      field.hidden = !shown
      field.querySelectorAll("input, select").forEach((input) => { input.disabled = !shown })
    })
  }
  form.addEventListener("change", (event) => { if (event.target.name === "service_type") sync() })
  form.addEventListener("reset", () => setTimeout(sync))
  sync()
})

// CookieBanner.svelte: shown until the visitor answers; the answer is kept
// (mb_cookie_consent, as the Astro site kept it) and announced as
// "cookie-consent" for anything that waits on it.
const banner = document.querySelector("[data-cookie-banner]")
if (banner) {
  const KEY = "mb_cookie_consent"
  const VERSION = "1"
  let stored = null
  try { stored = localStorage.getItem(KEY) } catch { stored = null }
  if (!stored?.endsWith(`:${VERSION}`)) banner.hidden = false
  banner.querySelectorAll("[data-cookie-choice]").forEach((button) => button.addEventListener("click", () => {
    const value = button.dataset.cookieChoice
    const payload = `${value}:${VERSION}`
    try { localStorage.setItem(KEY, payload) } catch { /* private mode: the cookie still keeps it */ }
    document.cookie = `${KEY}=${encodeURIComponent(payload)};path=/;max-age=${60 * 60 * 24 * 365};SameSite=Lax`
    banner.hidden = true
    window.dispatchEvent(new CustomEvent("cookie-consent", { detail: { value } }))
  }))
}
