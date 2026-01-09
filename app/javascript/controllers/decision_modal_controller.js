import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog", "form", "titleLabel", "statusInput", "vendorInput", "notesInput"];
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

    console.debug("DecisionModalController: fetching decision item", { itemId, url });

    fetch(url)
      .then((response) => {
        console.debug("DecisionModalController: fetch completed", {
          itemId,
          url,
          status: response.status,
          ok: response.ok
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }

        return response.json();
      })
      .then((data) => {
        console.debug("DecisionModalController: received payload", { itemId, data });
        this.populateForm(data);
        this.showModal();
      })
      .catch((error) => {
        console.error("DecisionModalController: unable to load decision", { itemId, url, error });
        alert(`Unable to load decision (${error.message}). Please try again.`);
      });
  }

  populateForm(data) {
    const item = data.calendar_item;
    if (this.hasTitleLabelTarget) {
      this.titleLabelTarget.textContent = item.title || "Edit Decision";
    }
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
