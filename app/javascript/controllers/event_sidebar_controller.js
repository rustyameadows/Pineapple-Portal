import { Controller } from "@hotwired/stimulus";

const DEFAULT_COLLAPSED_CLASS = "event-sidebar--collapsed";
const DEFAULT_STORAGE_KEY = "event-sidebar-collapsed";

export default class extends Controller {
  static targets = ["toggleLabel", "toggleButton"];
  static values = {
    collapsedClass: String,
    storageKey: String
  };

  connect() {
    this.collapsedClass = this.collapsedClassValue || DEFAULT_COLLAPSED_CLASS;
    this.storageKey = this.storageKeyValue || DEFAULT_STORAGE_KEY;

    const storedPreference = this.readStoredPreference();
    if (storedPreference) {
      this.applyCollapsed(storedPreference === "true", { updateStorage: false });
    } else {
      this.updateToggleLabel();
      this.updateToggleTitle();
    }
  }

  toggle(event) {
    event.preventDefault();
    const shouldCollapse = !this.element.classList.contains(this.collapsedClass);
    this.applyCollapsed(shouldCollapse);
  }

  applyCollapsed(collapsed, { updateStorage = true } = {}) {
    this.element.classList.toggle(this.collapsedClass, collapsed);

    if (updateStorage) {
      if (collapsed) {
        window.localStorage.setItem(this.storageKey, "true");
      } else {
        window.localStorage.removeItem(this.storageKey);
      }
    }

    const expanded = (!collapsed).toString();
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute("aria-expanded", expanded);
    }

    this.updateToggleLabel();
    this.updateToggleTitle();
  }

  updateToggleLabel() {
    if (!this.hasToggleLabelTarget) return;
    const collapsed = this.element.classList.contains(this.collapsedClass);
    this.toggleLabelTarget.textContent = collapsed ? "Expand" : "Collapse";
  }

  updateToggleTitle() {
    if (!this.hasToggleButtonTarget) return;
    const collapsed = this.element.classList.contains(this.collapsedClass);
    this.toggleButtonTarget.setAttribute("title", collapsed ? "Expand navigation" : "Collapse navigation");
  }

  readStoredPreference() {
    try {
      return window.localStorage.getItem(this.storageKey);
    } catch (_error) {
      return null;
    }
  }
}
