import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog", "form", "titleInput", "statusInput", "vendorInput", "notesInput"];
  static values = { basePath: String };

  open(event) {
    const trigger = event.currentTarget;
    const itemId = trigger.dataset.decisionModalItemIdValue;
    this.fetchItem(itemId);
  }

  close() {
    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close();
    } else {
      this.dialogTarget.removeAttribute("open");
    }
  }

  fetchItem(itemId) {
    const url = this.basePathValue.replace("__ITEM__", itemId) + ".json";

    fetch(url)
      .then((response) => {
        if (!response.ok) throw new Error("Network response was not ok");
        return response.json();
      })
      .then((data) => this.populateForm(data))
      .then(() => this.showModal())
      .catch(() => alert("Unable to load decision. Please try again."));
  }

  populateForm(data) {
    const item = data.calendar_item;
    this.titleInputTarget.value = item.title || "";
    this.statusInputTarget.value = item.status || "planned";
    this.vendorInputTarget.value = item.vendor_name || "";
    this.notesInputTarget.value = item.notes || "";
    this.formTarget.action = this.basePathValue.replace("__ITEM__", item.id);
  }

  showModal() {
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal();
    } else {
      this.dialogTarget.setAttribute("open", "open");
    }
  }
}
