import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
	static targets = ["service", "namespace"];

	toggleParent({ target: element }) {
		this.#matchChildrenStateToParent(element);
	}

	toggleChild() {
		this.#maybeSetParentIntermediate();
	}

	#matchChildrenStateToParent(parent) {
		const checked = parent.checked;
		this.namespaceTargets.forEach((namespace) => (namespace.checked = checked));
	}

	#maybeSetParentIntermediate() {
		const totalSelected = this.namespaceTargets.reduce(
			(total, namespace) => (namespace.checked ? total + 1 : total),
			0,
		);

		const [checked, indeterminate] =
			totalSelected == 0
				? [false, false]
				: totalSelected != this.namespaceTargets.length
					? [false, true]
					: [true, false];

		Object.assign(this.serviceTarget, {
			checked: checked,
			indeterminate: indeterminate,
		});
	}
}
