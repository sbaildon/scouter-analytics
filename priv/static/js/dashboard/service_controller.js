import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
	static targets = ["service", "host"];

	toggleParent({ target: element }) {
		this.#matchChildrenStateToParent(element);
	}

	toggleChild() {
		this.#maybeSetParentIntermediate();
	}

	#matchChildrenStateToParent(parent) {
		const checked = parent.checked;
		this.hostTargets.forEach((host) => (host.checked = checked));
	}

	#maybeSetParentIntermediate() {
		const totalSelected = this.hostTargets.reduce(
			(total, host) => (host.checked ? total + 1 : total),
			0,
		);

		const [checked, indeterminate] =
			totalSelected == 0
				? [false, false]
				: totalSelected != this.hostTargets.length
					? [false, true]
					: [true, false];

		Object.assign(this.serviceTarget, {
			checked: checked,
			indeterminate: indeterminate,
		});
	}
}
